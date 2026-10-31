import Foundation
import SwiftData

/// Prefilled values (previous session, goal, carry notes) and resuming a session already started.
extension WorkoutViewModel {
    /// Previous session's work sets for this exercise in this gym, in order (excludes the running session).
    func previousSets(of exerciseID: UUID) -> [SetLog] {
        if let cached = previousCache[exerciseID] { return cached }
        let gymID = session.gymID
        let current = session.id
        var descriptor = FetchDescriptor<SetLog>(
            predicate: #Predicate {
                $0.exerciseID == exerciseID && $0.gymID == gymID && $0.kindRaw == "work" && $0.sessionID != current
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        // Sets done during a deload week are lighter on purpose: they must not set the next goal,
        // unless the exercise was only ever done in one (new rehab exercise): its weights are still right.
        let all = (try? context.fetch(descriptor)) ?? []
        // Same for a day marked « Fatigué »: lighter on purpose, it is not the level to start from.
        let tired = tiredSessions(among: Set(all.map(\.sessionID)))
        let normal = all.filter { !cycle.isDeload($0.completedAt) && !tired.contains($0.sessionID) }
        let logs = normal.isEmpty ? all : normal
        // A session logged without weights (forgotten) must not reset the exercise to 0: the last one with a weight counts.
        let latest = (logs.first { $0.weight > 0 } ?? logs.first)?.sessionID
        let result = logs.filter { $0.sessionID == latest }.sorted { $0.index < $1.index }
        previousCache[exerciseID] = result
        return result
    }

    /// The sessions among these marked « Fatigué » (stored with the session id as exercise id).
    func tiredSessions(among ids: Set<UUID>) -> Set<UUID> {
        guard !ids.isEmpty else { return [] }
        let tired = Feeling.tired.rawValue
        let marks = (try? context.fetch(FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { $0.feelingRaw == tired }))) ?? []
        return Set(marks.filter { $0.isSessionWide && ids.contains($0.sessionID) }.map(\.sessionID))
    }

    /// The strength scale of this person against the program's starting weights, from the exercises of this session already done (once).
    func startScale() -> Double {
        if let startScaleCache { return startScaleCache }
        var seen: Set<UUID> = []
        let pairs: [(actual: Double, start: Double)] = steps.compactMap { step in
            guard seen.insert(step.exerciseID).inserted, let start = ProgramCatalog.exercise(named: step.name)?.start,
                  let best = previousSets(of: step.exerciseID).map(\.weight).max(), best > 0 else { return nil }
            return (best, start)
        }
        let scale = StartWeight.scale(pairs)
        startScaleCache = scale
        return scale
    }

    func goal(for step: WorkoutStep) -> Progression.Target? {
        let last = previousSets(of: step.exerciseID)
        let lastSets = last.map { (weight: $0.weight, reps: $0.reps) }
        let efforts = last.compactMap { $0.rir.map { Double(10 - $0) } }
        let info = ProgramCatalog.exercise(named: step.name)
        let unit = max(step.progressionStep, 0.5)
        var target: Progression.Target?
        // Never done here: the program's starting weight, scaled by what has really been lifted on the others.
        if last.isEmpty, let start = info?.start, step.unit.isEmpty {
            let weight = StartWeight.weight(start: start, scale: startScale(), step: step.progressionStep)
            return weight > 0 ? Progression.Target(weight: weight, reps: step.repsMin, increased: false) : nil
        }
        // « Gêne » last time on this exercise: nothing is pushed (rehab: ≤ 3/10, otherwise no extra plate).
        let painLastTime = last.first.map { painIn(session: $0.sessionID, exerciseID: step.exerciseID) } ?? false
        if isDeload || isTired || painLastTime || (info?.weekly == true && raisedThisWeek(step.exerciseID)) {
            target = Progression.hold(lastSets: lastSets, repsMin: step.repsMin, repsMax: step.repsMax)
        } else {
            target = Progression.target(
                lastSets: lastSets, repsMin: step.repsMin, repsMax: step.repsMax, step: step.progressionStep,
                averageRPE: efforts.isEmpty ? nil : efforts.reduce(0, +) / Double(efforts.count),
                targetRPE: Double(10 - step.targetRIR)
            )
        }
        guard var target else { return nil }
        // New execution with the new program (slower tempo…): the old weight is cut once.
        if let factor = info?.loadFactor, factor < 1, let date = last.first?.completedAt, date < (cycle.programLoadedAt ?? .distantPast) {
            target.weight = (target.weight * factor / unit).rounded() * unit
            target.increased = false
        }
        if let shift = adjustments.shift[step.exerciseID], !(isTired && shift > 0) {
            target = Progression.shifted(target, by: shift, heaviest: lastSets.map(\.weight).max(), step: step.progressionStep)
        }
        if adjustments.weightFactor < 1 {
            target.weight = (target.weight * adjustments.weightFactor / unit).rounded() * unit
            target.increased = false
        }
        // On a weight the machine really has (learned from what was typed on it in this gym).
        target.weight = WeightGrid.snap(
            target.weight, known: knownWeights(of: step.exerciseID), last: lastSets.map(\.weight).max(), maxStep: 2 * unit
        )
        return target
    }

    /// A warmup's weight: % of the work weight, on a weight the machine has, never above the work weight.
    func warmupWeight(work: Double, percent: Double, step: WorkoutStep) -> Double {
        let warm = WarmupCalculator.weight(work: work, percent: percent, step: step.progressionStep)
        guard warm > 0 else { return warm }
        let snapped = WeightGrid.snap(warm, known: knownWeights(of: step.exerciseID), last: nil, maxStep: 2 * max(step.progressionStep, 0.5))
        return snapped < work ? snapped : warm
    }

    /// Every work weight typed on this exercise in this gym (the machine's real weights), cached per session.
    func knownWeights(of exerciseID: UUID) -> [Double] {
        if let cached = knownCache[exerciseID] { return cached }
        let gymID = session.gymID
        let current = session.id
        var descriptor = FetchDescriptor<SetLog>(predicate: #Predicate {
            $0.exerciseID == exerciseID && $0.gymID == gymID && $0.kindRaw == "work" && $0.sessionID != current
        }, sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        descriptor.fetchLimit = 300
        let known = WeightGrid.known(((try? context.fetch(descriptor)) ?? []).map(\.weight))
        knownCache[exerciseID] = known
        return known
    }

    func painIn(session sessionID: UUID, exerciseID: UUID) -> Bool {
        var descriptor = FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { $0.exerciseID == exerciseID && $0.sessionID == sessionID })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.feeling == .pain
    }

    /// The load went up at a session of the last 6 days (rehab: one plate a week at most).
    func raisedThisWeek(_ exerciseID: UUID) -> Bool {
        if let cached = raisedCache[exerciseID] { return cached }
        let raised = computeRaisedThisWeek(exerciseID)
        raisedCache[exerciseID] = raised
        return raised
    }

    func computeRaisedThisWeek(_ exerciseID: UUID) -> Bool {
        let gymID = session.gymID
        let current = session.id
        let since = Calendar.current.date(byAdding: .day, value: -13, to: session.startedAt) ?? session.startedAt
        let logs = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate {
            $0.exerciseID == exerciseID && $0.gymID == gymID && $0.kindRaw == "work" && $0.sessionID != current && $0.completedAt >= since
        }))) ?? []
        let tops = Dictionary(grouping: logs, by: \.sessionID).values
            .map { (date: $0.map(\.completedAt).max() ?? .distantPast, top: $0.map(\.weight).max() ?? 0) }
            .sorted { $0.date > $1.date }
        guard tops.count >= 2, session.startedAt.timeIntervalSince(tops[0].date) < 6 * 86_400 else { return false }
        return tops[0].top > tops[1].top
    }

    /// Prefills weight/reps: double-progression goal for work sets, % of it for warmups.
    func applyDefaults(to indices: [Int]) {
        previousCache = previousCache.filter { key, _ in !indices.contains { steps[$0].exerciseID == key } }
        for i in indices {
            let step = steps[i]
            if let percent = step.warmupPercent {
                // A warmup follows the work weight of its exercise; none to do when that weight is 0 (bodyweight).
                let workStep = steps.first { $0.warmupPercent == nil && $0.exerciseID == step.exerciseID && $0.blockIndex == step.blockIndex }
                let work = workStep.flatMap(goal(for:))?.weight ?? 0
                if work <= 0, !done.contains(i) {
                    skipped.insert(i)
                    noWeightYet.insert(i)
                }
                values[i] = SetValues(
                    weight: warmupWeight(work: work, percent: percent, step: step),
                    reps: step.repsMin
                )
            } else {
                let target = goal(for: step)
                values[i] = SetValues(
                    weight: Diagnostics.finite(target?.weight ?? 0, "default weight of \(step.exerciseID)"),
                    reps: target?.reps ?? step.repsMin
                )
            }
        }
    }

    /// Carry notes: first shown greyed in this session, deleted when a later session reaches the exercise.
    func rollCarryNotes() {
        let current = session.id
        let exerciseIDs = Set(steps.map(\.exerciseID))
        let notes = (try? context.fetch(FetchDescriptor<CarryNote>(predicate: #Predicate { $0.sessionID != current }))) ?? []
        for note in notes where exerciseIDs.contains(note.exerciseID) {
            if let shown = note.carrySessionID {
                if shown != current { context.delete(note) }
            } else {
                note.carrySessionID = current
            }
        }
        context.saveReportingFailure()
    }

    /// Restores the sets already logged for this session (and the exercises swapped before closing).
    /// A log goes back to its own row; when the plan changed since (program edit, other warmups), it is matched to the
    /// same exercise, kind and side instead of landing on whatever sits at its old index.
    func resume(exercises: [UUID: Exercise]) {
        let sessionID = session.id
        let logs = ((try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == sessionID }))) ?? [])
            .sorted { $0.index < $1.index }
        let planned = Set(steps.map(\.exerciseID))
        var claimed: Set<Int> = []
        var restored: [(log: SetLog, index: Int)] = []
        var moved = false
        func fits(_ i: Int, _ log: SetLog) -> Bool {
            steps.indices.contains(i) && !claimed.contains(i)
                && (steps[i].warmupPercent == nil) == (log.kind == .work) && steps[i].side == log.side
        }
        for log in logs {
            let sameExercise = steps.indices.first { fits($0, log) && steps[$0].exerciseID == log.exerciseID }
            let target: Int?
            if fits(log.index, log), steps[log.index].exerciseID == log.exerciseID {
                target = log.index
            } else if fits(log.index, log), !planned.contains(log.exerciseID) {
                target = log.index
            } else {
                target = sameExercise ?? (fits(log.index, log) ? log.index : nil)
            }
            guard let i = target else { continue }
            claimed.insert(i)
            if log.index != i {
                log.index = i
                moved = true
            }
            restored.append((log, i))
        }
        if moved { context.saveReportingFailure() }
        for (log, i) in restored {
            if log.exerciseID != steps[i].exerciseID {
                steps[i].exerciseID = log.exerciseID
                steps[i].name = exercises[log.exerciseID]?.name ?? steps[i].name
            }
            values[i] = SetValues(weight: log.weight, reps: log.reps, rpe: log.rir.map { min(max(10 - $0, 1), 10) })
            done.insert(i)
        }
        lastTouched = restored.max { $0.log.completedAt < $1.log.completedAt }?.index
        // Warmups of an exercise whose work sets were started count as skipped.
        let started = Set(restored.filter { $0.log.kind == .work }.map { steps[$0.index].exerciseID })
        for i in steps.indices where steps[i].warmupPercent != nil && !done.contains(i) && started.contains(steps[i].exerciseID) {
            skipped.insert(i)
        }
    }
}
