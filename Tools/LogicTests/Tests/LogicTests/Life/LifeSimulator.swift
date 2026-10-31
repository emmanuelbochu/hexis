import Foundation
import SwiftData
@testable import HexisLogic

/// Lives months of training with the real app: the real program file, the real database schema and the real workout view
/// model, driven like a thumb would (weights typed, efforts picked, sets ticked, sessions forgotten). Every session is
/// checked against `LifeChecks`; what breaks lands in `violations` with the week, the session and the exercise.
@MainActor
final class LifeSimulator {
    struct Stats {
        var sessions = 0
        var workSets = 0
        /// Sets where the suggested weight left fewer than the minimum reps minus 2 (the person had to drop it).
        var overshoots = 0
        /// Suggested weight ÷ the ideal one, once the app knows the exercise (3 sessions in that gym).
        var ratios: [Double] = []
        var deloads = 0
        var forgotten = 0
    }

    let context: ModelContext
    private let container: ModelContainer
    private(set) var athlete: Athlete
    private(set) var violations: [String] = []
    private(set) var stats = Stats()
    private let gyms: [Gym]
    private let location = LocationService()
    private let start: Date
    private var where_ = ""
    /// Heaviest work weight done last time, per exercise and gym (typos excluded): the reference for a sane jump.
    private var lastTop: [String: Double] = [:]
    private var sessionsDone: [String: Int] = [:]
    private var lastTrainedWeek = 0

    static let calendar = WeekReview.calendar
    nonisolated static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    nonisolated static let programFile = repo.appendingPathComponent("Hexis/Resources/Program.json")
    /// Hexis Elle's program: same app, same rules, her own file.
    nonisolated static let herProgramFile = repo.appendingPathComponent("HexisElle/Program.json")

    /// The program of the app being tested (the ELLE pass of `logic_tests.sh` is her app).
    #if ELLE
    nonisolated static let appProgramFile = herProgramFile
    #else
    nonisolated static let appProgramFile = programFile
    #endif

    init(habits: Habits, seed: UInt64, program: URL = appProgramFile) throws {
        ProgramCatalog.fileURL = program
        for key in ["programFileHash", "programStructureHash", ProgramSync.startKey] { UserDefaults.standard.removeObject(forKey: key) }
        container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        athlete = Athlete(habits: habits, seed: seed)
        // A Monday in the past: nothing the app timestamps with the real clock lands before the simulated days.
        start = Self.calendar.date(from: DateComponents(year: 2025, month: 1, day: 6, hour: 18)) ?? .distantPast
        ProgramSync.sync(in: context)
        UserDefaults.standard.set(start, forKey: ProgramSync.startKey)
        gyms = [Gym(name: "Salle CityA"), Gym(name: "Salle CityB")]
        gyms.forEach(context.insert)
        try context.save()
    }

    // MARK: - Life

    func live(weeks: Int) async {
        var holidayLeft = 0
        let days: [Int] = switch athlete.habits.sessionsPerWeek {
        case ...2: [1, 4]
        case 3: [0, 2, 4]
        case 4: [0, 1, 3, 4]
        default: [0, 1, 2, 4, 5]
        }
        for week in 0..<weeks {
            if holidayLeft > 0 { holidayLeft -= 1; continue }
            if week > 2, athlete.dice.chance(athlete.habits.holiday) { holidayLeft = Int.random(in: 0...1, using: &athlete.dice); continue }
            for day in days where !athlete.dice.chance(athlete.habits.skip) {
                let minutes = Int.random(in: -60...90, using: &athlete.dice)
                let now = start.addingTimeInterval(Double(week * 7 + day) * 86_400 + Double(minutes) * 60)
                await train(on: now, week: week)
            }
        }
        await launchChores(now: start.addingTimeInterval(Double(weeks * 7) * 86_400))
        stats.deloads = (try? context.fetchCount(FetchDescriptor<DeloadWeek>())) ?? 0
    }

    /// What `RootView` and `HomeView` do when the app opens: forgotten sessions closed, a deload planned when due.
    private func launchChores(now: Date) async {
        let open = (try? context.fetchCount(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "inProgress" }))) ?? 0
        let closed = await SessionCloser.run(in: context, location: location, now: now)
        stats.forgotten += min(open, closed.count)
        AutoDeload.planIfDue(in: context, now: now)
        violations += LifeChecks.store(context, now: now).map { "\(stamp(now)) · \($0)" }
    }

    private func train(on now: Date, week: Int) async {
        athlete.detrain(weeks: week - lastTrainedWeek)
        lastTrainedWeek = week
        await launchChores(now: now)
        guard let template = nextTemplate(now: now) else { return violations.append("\(stamp(now)) · aucune séance proposée") }
        let gym = athlete.dice.chance(athlete.habits.otherGym) ? gyms[1] : gyms[0]
        let session = WorkoutSession(date: now, gymID: gym.id, templateID: template.id)
        context.insert(session)
        context.saveReportingFailure()
        let vm = WorkoutViewModel(session: session, template: template, context: context)
        where_ = "\(stamp(now)) \(template.name)"
        stats.sessions += 1
        violations += LifeChecks.plan(vm, lastTop: lastTop, gymID: gym.id).map { "\(where_) · \($0)" }

        let tired = athlete.dice.chance(athlete.habits.tired)
        if tired { vm.toggleTired() }
        if athlete.dice.chance(athlete.habits.pain), let exercise = vm.steps.randomElement(using: &athlete.dice)?.exerciseID { vm.togglePain(exercise) }

        var blocks = Dictionary(grouping: vm.steps.indices, by: { vm.steps[$0].blockIndex }).sorted { $0.key < $1.key }.map(\.value)
        if athlete.dice.chance(athlete.habits.shuffle) { blocks.shuffle(using: &athlete.dice) }
        let order = blocks.flatMap { $0 }
        let leaveAt = athlete.dice.chance(athlete.habits.leaveEarly) ? order.count / 2 : order.count
        var clock = now
        var setsOf: [UUID: Int] = [:]
        var tops: [String: Double] = [:]
        for i in order.prefix(leaveAt) where !vm.done.contains(i) && !vm.skipped.contains(i) {
            let step = vm.steps[i]
            let key = Athlete.key(step.exerciseID, gym.id)
            let isLast = vm.steps.indices.last { vm.steps[$0].exerciseID == step.exerciseID && vm.steps[$0].warmupPercent == nil } == i
            if let top = perform(i, vm: vm, key: key, fatigue: 0.03 * Double(setsOf[step.exerciseID, default: 0]) + (tired ? 0.05 : 0), last: isLast, isDeload: vm.isDeload || tired) {
                tops[key] = max(tops[key] ?? 0, top)
            }
            if step.warmupPercent == nil { setsOf[step.exerciseID, default: 0] += 1 }
            if let log = try? context.fetch(FetchDescriptor<SetLog>(predicate: Self.logAt(session.id, i))).first { log.completedAt = clock }
            clock.addTimeInterval(Double(max(vm.values[i]?.reps ?? 8, 1)) * 3.5 + Double(step.restAfter) * athlete.dice.between(0.9...1.3))
        }
        context.saveReportingFailure()
        if vm.isAllDone {
            vm.finish()
            session.endedAt = clock
            context.saveReportingFailure()
        }
        for (key, top) in tops {
            // A « Fatigué » day is not the next session's reference (the app goes back to the weight before it): nor is it here.
            if !vm.isDeload && !tired { lastTop[key] = top }
            sessionsDone[key, default: 0] += 1
            athlete.trained(key, week: week)
        }
    }

    /// Does one set like a person: takes the suggestion, lowers it when it is far too heavy, stops near the target effort.
    /// Returns the weight lifted on a work set.
    private func perform(_ i: Int, vm: WorkoutViewModel, key: String, fatigue: Double, last: Bool, isDeload: Bool) -> Double? {
        let step = vm.steps[i]
        guard step.warmupPercent == nil else { vm.toggle(i); return nil }
        stats.workSets += 1
        var weight = vm.values[i]?.weight ?? 0
        if !step.unit.isEmpty || step.progressionStep <= 0 {
            vm.setReps(i, max(vm.values[i]?.reps ?? 0, step.repsMin))
            vm.toggle(i)
            return nil
        }
        if weight <= 0 {
            if athlete.everLoaded.contains(key) { violations.append("\(where_) · \(step.name) : 0 kg proposé alors qu'il était chargé\(vm.isDeload ? " (déload)" : "")") }
            weight = athlete.firstWeight(key, repsMax: step.repsMax, step: step.progressionStep)
            vm.setWeight(i, weight)
        } else if (sessionsDone[key] ?? 0) >= 3, !isDeload, step.setNumber == 1 {
            let ideal = athlete.idealWeight(key, reps: step.repsMax, rir: step.targetRIR, step: step.progressionStep)
            stats.ratios.append(weight / ideal)
        }
        var capacity = athlete.capacity(key, weight: weight, step: step.progressionStep, fatigue: fatigue)
        if capacity < Double(step.repsMin - 2) {
            if (sessionsDone[key] ?? 0) >= 2 { stats.overshoots += 1 }
            let fits = athlete.idealWeight(key, reps: step.repsMin, rir: 1, step: step.progressionStep) * (1 - fatigue)
            weight = max(step.progressionStep, (fits / step.progressionStep).rounded(.down) * step.progressionStep)
            vm.setWeight(i, weight)
            capacity = athlete.capacity(key, weight: weight, step: step.progressionStep, fatigue: fatigue)
        }
        let reserve = Double(step.targetRIR) + athlete.dice.between(-0.5...1)
        var reps = Int((capacity - reserve).rounded(.down))
        reps = min(reps, step.repsMax + (athlete.dice.chance(0.15) ? 1 : 0))
        reps = max(reps, min(Int(capacity), step.repsMin), 0)
        vm.setReps(i, reps)
        let rpe = Int(min(10, max(5, (10 - (capacity - Double(reps))).rounded())))
        let typo = last && athlete.dice.chance(athlete.habits.typo)
        if typo { vm.setWeight(i, weight * 10) }
        if athlete.dice.chance(athlete.habits.noEffort) { vm.toggle(i) } else { vm.setRPE(i, rpe) }
        return weight
    }

    /// The session the home screen proposes (`WeekRotation`: usual order, or the 3-session variant when the week is short).
    private func nextTemplate(now: Date) -> WorkoutTemplate? {
        let templates = (try? context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive })))?.first?.templates ?? []
        let finished = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? []
        let id = WeekRotation.make(templates: templates, sessions: finished.map { ($0.templateID, $0.startedAt) }, now: now).next
        return templates.first { $0.id == id }
    }

    private static func logAt(_ session: UUID, _ index: Int) -> Predicate<SetLog> {
        #Predicate { $0.sessionID == session && $0.index == index }
    }

    private func stamp(_ date: Date) -> String {
        let days = Self.calendar.dateComponents([.day], from: start, to: date).day ?? 0
        return "S\(days / 7 + 1) J\(days % 7 + 1)"
    }
}
