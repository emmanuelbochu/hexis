import Foundation
import Observation
import SwiftData

/// Editable weight/reps of one planned set.
struct SetValues: Equatable {
    var weight: Double
    var reps: Int
    /// Perceived effort 1–10 (stored as reps in reserve, `SetLog.rir = 10 - rpe`).
    var rpe: Int?
}

@Observable
final class WorkoutViewModel {
    let session: WorkoutSession
    let templateName: String
    /// Planned order; the position of a step is its `SetLog.index`.
    var steps: [WorkoutStep] { didSet { rebuildGroups() } }
    /// Exercises of the session in order, rebuilt only when the steps change.
    var groups: [ExerciseGroup] = []
    @ObservationIgnored var supersetOrder: [Int: Int] = [:]
    let rest = RestTimer()
    var values: [Int: SetValues] = [:]
    var done: Set<Int> = []
    var skipped: Set<Int> = []
    /// Warmups hidden only because their work weight was 0 (no history): they come back when a weight is typed.
    var noWeightYet: Set<Int> = []
    /// How the weight is typed for each exercise (per side, stack…), as chosen by the user.
    var loads: [UUID: LoadProfile] = [:]
    /// Deload weeks and program start; a deload session keeps its loads with half the sets.
    @ObservationIgnored var cycle = TrainingCycle(deloadStarts: [])
    private(set) var isDeload = false
    /// What the app changed by itself for this session (rests, back-off); told on the home screen.
    private(set) var adjustments = SessionAdjustments.none
    @ObservationIgnored var diagnoses: [AIInsight]?
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored var startScaleCache: Double?
    @ObservationIgnored var previousCache: [UUID: [SetLog]] = [:]
    @ObservationIgnored var feelingCache: [UUID: Feeling?] = [:]
    @ObservationIgnored var priorCache: [UUID: [LiveRecord.Prior]] = [:]
    /// « Gêne » per exercise and « Fatigué » (stored under the session id) of this session, read once: the views ask for them on every redraw.
    var sessionFeelings: [UUID: Feeling] = [:]
    @ObservationIgnored var raisedCache: [UUID: Bool] = [:]
    /// Real weights of each machine in this gym (`WeightGrid`), read once.
    @ObservationIgnored var knownCache: [UUID: [Double]] = [:]

    /// The set the user last touched: the session carries on from there, wherever it started (machine taken, other order).
    var lastTouched: Int?

    /// Set to do now, highlighted and scrolled to: the next one after the last set touched, then back to what was left behind.
    var currentIndex: Int? {
        func pending(_ i: Int) -> Bool { !done.contains(i) && !skipped.contains(i) }
        let from = lastTouched ?? 0
        return steps.indices.first { $0 >= from && pending($0) } ?? steps.indices.first(where: pending)
    }
    var isAllDone: Bool { currentIndex == nil }

    init(session: WorkoutSession, template: WorkoutTemplate, context: ModelContext) {
        self.session = session
        self.templateName = template.name
        self.context = context
        let exercises = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.id, $0) }
        )
        let cycle = TrainingCycle.load(context: context)
        let adjustments = SessionAdjuster.load(
            template: template, gymID: session.gymID, context: context, now: session.startedAt, excluding: session.id, persist: true
        )
        steps = WorkoutPlanner.steps(
            for: SessionPlan.blocks(template: template, exercises: exercises, adjustments: adjustments),
            warmupPercents: WarmupCalculator.defaultPercents
        )
        for load in (try? context.fetch(FetchDescriptor<ExerciseLoad>())) ?? [] {
            loads[load.exerciseID] = LoadProfile(kind: load.kind, base: load.baseWeight)
        }
        rebuildGroups()
        self.cycle = cycle
        self.adjustments = adjustments
        isDeload = adjustments.isDeload
        for i in steps.indices where steps[i].warmupPercent == nil && steps[i].restAfter >= SessionAdjuster.minRest {
            if let delta = adjustments.restDelta[steps[i].exerciseID] { steps[i].restAfter = max(SessionAdjuster.minRest, steps[i].restAfter + delta) }
        }
        let sessionID = session.id
        for entry in (try? context.fetch(FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { $0.sessionID == sessionID }))) ?? [] {
            sessionFeelings[entry.exerciseID] = entry.feeling
        }
        applyDefaults(to: Array(steps.indices))
        resume(exercises: exercises)
        rollCarryNotes()
        NotificationService.requestAuthorization()
    }

    // MARK: - Editing

    /// Changing a set also changes the other sets of the exercise still to do that had the same value
    /// (a set edited on purpose, e.g. a drop set, is left alone).
    func setWeight(_ i: Int, _ weight: Double) {
        let old = values[i]?.weight
        let new = max(0, weight)
        values[i, default: SetValues(weight: 0, reps: 0)].weight = new
        for j in linkedSets(of: i) where values[j]?.weight == old { values[j]?.weight = new }
        refreshWarmups(near: i)
    }

    func setReps(_ i: Int, _ reps: Int) {
        let old = values[i]?.reps
        let new = max(0, reps)
        values[i, default: SetValues(weight: 0, reps: 0)].reps = new
        for j in linkedSets(of: i) where values[j]?.reps == old { values[j]?.reps = new }
    }

    /// Work sets of the same exercise (same block) that are not done yet, other than `i`.
    func linkedSets(of i: Int) -> [Int] {
        let step = steps[i]
        guard step.warmupPercent == nil else { return [] }
        return steps.indices.filter {
            $0 != i && !done.contains($0) && steps[$0].warmupPercent == nil
                && steps[$0].exerciseID == step.exerciseID && steps[$0].blockIndex == step.blockIndex
        }
    }

    /// Records the effort of a set: validates it (and starts the rest) when it is not done yet.
    func setRPE(_ i: Int, _ rpe: Int) {
        guard steps.indices.contains(i) else { return }
        values[i, default: SetValues(weight: 0, reps: steps[i].repsMin)].rpe = rpe
        if done.contains(i) {
            let sessionID = session.id
            let logs = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == sessionID && $0.index == i }))) ?? []
            logs.forEach { $0.rir = 10 - rpe }
            context.saveReportingFailure()
        } else {
            toggle(i)
        }
    }

    /// Effort suggested when the gauge opens: the one set the last time, else the template's RIR target.
    func suggestedRPE(_ i: Int) -> Int {
        values[i]?.rpe ?? (10 - steps[i].targetRIR)
    }

    /// Checks a set (logs it, starts the rest) or unchecks it (removes the log).
    func toggle(_ i: Int) {
        guard steps.indices.contains(i) else { return }
        if done.contains(i) {
            let sessionID = session.id
            let logs = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == sessionID && $0.index == i }))) ?? []
            logs.forEach(context.delete)
            context.saveReportingFailure()
            done.remove(i)
            lastTouched = i
            return
        }
        let step = steps[i]
        let entry = values[i] ?? SetValues(weight: 0, reps: step.repsMin)
        context.insert(SetLog(
            sessionID: session.id, exerciseID: step.exerciseID, gymID: session.gymID, index: i,
            kind: step.warmupPercent == nil ? .work : .warmup, weight: entry.weight, reps: entry.reps,
            rir: step.warmupPercent == nil ? entry.rpe.map { 10 - $0 } : nil, side: step.side
        ))
        context.saveReportingFailure()
        done.insert(i)
        lastTouched = i
        // The last set of the session stays silent: the end screen rings instead.
        let open = steps.indices.filter { !done.contains($0) && !skipped.contains($0) }
        if !open.isEmpty {
            let exerciseOver = !open.contains { steps[$0].exerciseID == step.exerciseID && steps[$0].blockIndex == step.blockIndex }
            SoundService.play(exerciseOver ? .exerciseDone : .setDone)
        }
        let upcoming = steps.indices.first { $0 > i && !done.contains($0) }.map { steps[$0].name } ?? "Dernière série"
        rest.start(seconds: step.restAfter, next: upcoming)
    }

    /// Re-derives the warmups still to do from the first work set's weight of the same exercise.
    func refreshWarmups(near i: Int) {
        let step = steps[i]
        let siblings = steps.indices.filter { steps[$0].exerciseID == step.exerciseID && steps[$0].blockIndex == step.blockIndex }
        guard let first = siblings.first(where: { steps[$0].warmupPercent == nil }), let work = values[first]?.weight else { return }
        let started = siblings.contains { steps[$0].warmupPercent == nil && done.contains($0) }
        for j in siblings where !done.contains(j) {
            guard let percent = steps[j].warmupPercent else { continue }
            values[j]?.weight = warmupWeight(work: work, percent: percent, step: steps[j])
            if work > 0, !started, noWeightYet.remove(j) != nil { skipped.remove(j) }
        }
    }

    /// Hides the not-yet-done warmups of a group.
    func skipWarmups(of group: ExerciseGroup) {
        for i in group.indices where steps[i].warmupPercent != nil && !done.contains(i) {
            skipped.insert(i)
            noWeightYet.remove(i)
        }
    }

    func hasPendingWarmups(_ group: ExerciseGroup) -> Bool {
        group.indices.contains { steps[$0].warmupPercent != nil && !done.contains($0) && !skipped.contains($0) }
    }

    /// Swaps the exercise for the sets of the group not done yet (machine taken).
    func replace(_ group: ExerciseGroup, with exercise: Exercise) {
        let pending = group.indices.filter { !done.contains($0) }
        for i in pending {
            steps[i].exerciseID = exercise.id
            steps[i].name = exercise.name
        }
        applyDefaults(to: pending)
    }

    func finish() {
        guard session.state != .finished else { return }
        rest.skip()
        // Nothing was done (« Terminer » by mistake): no empty session in the history, the week or the cycle.
        let sessionID = session.id
        if done.isEmpty, ((try? context.fetchCount(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == sessionID }))) ?? 0) == 0 {
            SessionCloser.discard(session, context: context)
            return
        }
        SessionCloser.finish(session, context: context)
    }

    /// Back to the session after it closed by itself (a set was forgotten).
    func reopen() {
        guard session.state == .finished else { return }
        session.state = .inProgress
        session.endedAt = nil
        context.saveReportingFailure()
    }

    /// The AI's reading of this exercise from the last sessions, when it stalled or dropped.
    func diagnosis(_ exerciseID: UUID) -> String? {
        if diagnoses == nil {
            diagnoses = (try? context.fetch(FetchDescriptor<AIInsight>(predicate: #Predicate { $0.kind == "progress" }))) ?? []
        }
        return ProgressDiagnosis.latest(for: exerciseID, in: diagnoses ?? [])
    }
}
