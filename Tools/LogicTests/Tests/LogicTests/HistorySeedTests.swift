import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// Her Hevy history, loaded once at launch: kept in her usual gym, calibrating the lifts she shares with the program (Smith and leg press
/// converted to one side), leaving the other lifts as history only, and safe to load twice.
@Suite(.serialized) struct HistorySeedTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let history = root.appendingPathComponent("HexisElle/HevyHistory.json")
    static let program = root.appendingPathComponent("HexisElle/Program.json")

    @MainActor func launch() throws -> (ModelContext, UserDefaults) {
        let defaults = try #require(UserDefaults(suiteName: "HistorySeedTests-\(UUID())"))
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        ProgramSync.sync(in: context, url: Self.program, defaults: defaults)
        defaults.set(Date(timeIntervalSince1970: 1_793_300_000), forKey: ProgramSync.startKey)
        #expect(HistorySeed.seed(in: context, url: Self.history, defaults: defaults))
        return (context, defaults)
    }

    func lastWeights(_ name: String, in context: ModelContext) throws -> [Double] {
        let exercise = try #require(try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == name })
        let id = exercise.id
        let sets = try context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.exerciseID == id }, sortBy: [SortDescriptor(\.completedAt, order: .reverse)]))
        let last = sets.first?.sessionID
        return sets.filter { $0.sessionID == last }.map(\.weight)
    }

    @Test @MainActor func everythingLandsInHerGymWithHerSessions() throws {
        let (context, _) = try launch()
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first { $0.id == sessions.first?.gymID })
        #expect(sessions.count > 20 && sessions.allSatisfy { $0.state == .finished && $0.gymID == gym.id })
        #expect(Edition.isElle ? gym.name == "Wake Up Form" : true)
        #expect(try context.fetch(FetchDescriptor<SetLog>()).allSatisfy { $0.gymID == gym.id && $0.reps > 0 && $0.kind == .work })
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let a = try #require(templates.first { $0.name == "Séance A" }), b = try #require(templates.first { $0.name == "Séance B" })
        let last = try #require(sessions.max { $0.startedAt < $1.startedAt })
        #expect(last.templateID == a.id, "26 October was a session 1 → A, so B comes next")
        #expect(sessions.contains { $0.templateID == b.id } && sessions.contains { $0.templateID == nil })
    }

    /// First sessions after the import: no lift is proposed far under what she really lifted (the ramp week is lighter on purpose, not by 10 %+).
    @Test @MainActor func proposedWeightsStayNearWhatSheLifted() throws {
        let (context, _) = try launch()
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let sets = try context.fetch(FetchDescriptor<SetLog>())
        let gymID = sets.first?.gymID
        var report: [String] = []
        for template in try context.fetch(FetchDescriptor<Program>()).first?.templates ?? [] {
            let session = WorkoutSession(date: .now, gymID: gymID, templateID: template.id)
            context.insert(session)
            let vm = WorkoutViewModel(session: session, template: template, context: context)
            for index in vm.steps.indices where vm.steps[index].warmupPercent == nil {
                let name = vm.steps[index].name
                guard let id = exercises.first(where: { $0.name == name })?.id, let proposed = vm.values[index]?.weight else { continue }
                let past = sets.filter { $0.exerciseID == id && $0.kind == .work }.sorted { $0.completedAt < $1.completedAt }
                guard let lastSession = past.last?.sessionID else { continue }
                let lastWeight = past.filter { $0.sessionID == lastSession }.map(\.weight).max() ?? 0
                if lastWeight > 0 { report.append("\(name) : \(lastWeight) → \(proposed)") }
                #expect(lastWeight == 0 || proposed >= lastWeight * 0.9, "\(name) : \(proposed) is more than 10 % under the \(lastWeight) she lifted")
            }
        }
        for line in report { print("proposed · \(line)") }
    }

    @Test @MainActor func sharedLiftsAreConvertedAndTheOthersAreOnlyHistory() throws {
        let (context, _) = try launch()
        #expect(try lastWeights("Squat Smith", in: context) == [15, 15, 15], "30 kg of plates in Hevy = 15 a side")
        #expect(try lastWeights("Presse à cuisses", in: context) == [50, 50, 50])
        #expect(try lastWeights("Tirage vertical", in: context) == [39, 39, 39])
        #expect(try lastWeights("Élévations latérales haltères", in: context) == [8, 8, 8])
        #expect(try lastWeights("Hip thrust machine", in: context) == [50, 50, 50], "Hevy's « barre » label: she only ever used the machine; its number is the machine's whole weight, nothing per side")
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let rowing = try #require(exercises.first { $0.name == "Rowing poulie assis, prise en V" })
        let load = try #require(try context.fetch(FetchDescriptor<ExerciseLoad>()).first { $0.exerciseID == rowing.id })
        #expect(load.kind == .stack, "the cable row is another machine than the plate-loaded Rowing machine: history only")
        #expect(!(try context.fetch(FetchDescriptor<SetLog>())).contains { $0.exerciseID == exercises.first { $0.name == "Rowing machine" }?.id }, "…and calibrates nothing")
        #expect(Set(exercises.map(\.name)).count == exercises.count, "no exercise twice")
    }

    @Test @MainActor func loadingTwiceAddsNothing() throws {
        let (context, defaults) = try launch()
        let before = try context.fetchCount(FetchDescriptor<SetLog>())
        #expect(!HistorySeed.seed(in: context, url: Self.history, defaults: defaults), "already loaded")
        defaults.removeObject(forKey: HistorySeed.versionKey)
        #expect(HistorySeed.seed(in: context, url: Self.history, defaults: defaults))
        #expect(try context.fetchCount(FetchDescriptor<SetLog>()) == before, "same session ids: nothing duplicated")
    }

    /// The next session starts from her real weights, the other lifts from the program's starts scaled by them, and no deload is pushed on day one.
    @Test @MainActor func nextSessionStartsFromWhatSheReallyLifts() throws {
        ProgramCatalog.fileURL = Self.program
        let (context, _) = try launch()
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let b = try #require(templates.first { $0.name == "Séance B" })
        let monday = Date(timeIntervalSince1970: 1_793_300_000 + 3 * 86_400)
        let gymID = try context.fetch(FetchDescriptor<WorkoutSession>()).first?.gymID
        let session = WorkoutSession(date: monday, gymID: gymID, templateID: b.id)
        context.insert(session)
        let vm = WorkoutViewModel(session: session, template: b, context: context)
        let firstWork = vm.steps.indices.filter { vm.steps[$0].warmupPercent == nil }
        let byName = Dictionary(firstWork.map { (vm.steps[$0].name, vm.values[$0]?.weight ?? 0) }, uniquingKeysWith: { first, _ in first })
        #expect(try #require(byName["Presse à cuisses"]) >= 50, "her 50 a side: the plateau of her old program is not held against her")
        #expect(try #require(byName["RDL"]) >= 17.5)
        #expect(byName.values.allSatisfy { $0 > 0 }, "every lift has a weight from the first set: \(byName)")
        // What `AutoDeload` asks the advisor, with the program's start (the test's defaults are not the app's).
        let start = WeekReview.weekStart(containing: Date(timeIntervalSince1970: 1_793_300_000))
        let cycle = TrainingCycle(deloadStarts: [], programStart: start, programLoadedAt: nil)
        let finished = try context.fetch(FetchDescriptor<WorkoutSession>())
        let sets = try context.fetch(FetchDescriptor<SetLog>())
        let plateaus = StagnationDetector.findings(sets: sets, feelings: [], cycle: cycle, now: monday).count
        let advice = DeloadAdvisor.advice(now: monday, sessionDates: finished.map(\.startedAt), deloadStarts: [], plateauCount: plateaus, programStart: start)
        #expect(advice == nil, "her history from before the program is no reason for a deload on day one: \(String(describing: advice))")
    }
}

/// What the app learns from sessions it did not record: nothing about time, rests or plateaus; the durations stand in only until
/// two real sessions exist; a deload week never shortens the usual duration.
@Suite struct ImportedHistoryLearningTests {
    private func session(_ template: UUID, daysAgo: Double, minutes: Double, imported: Bool) -> WorkoutSession {
        let start = Date(timeIntervalSince1970: 1_793_000_000 - daysAgo * 86_400)
        let s = WorkoutSession(id: imported ? UUID(uuidString: "6F1B6C9E-4A0E-5F64-9A53-0D6F4C5B7E11") ?? UUID() : UUID(), date: start, templateID: template)
        s.endedAt = start.addingTimeInterval(minutes * 60)
        s.state = .finished
        return s
    }

    @Test func importedSessionsAreRecognisedByTheirId() {
        #expect(HistorySeed.isImported(UUID(uuidString: "6F1B6C9E-4A0E-5F64-9A53-0D6F4C5B7E11") ?? UUID()))
        #expect((0..<200).allSatisfy { _ in !HistorySeed.isImported(UUID()) }, "the app's own ids are random v4")
    }

    @Test func importedDurationsOnlyStandInUntilTwoRealSessions() {
        let t = UUID()
        let old = (1...3).map { session(t, daysAgo: 30 + Double($0), minutes: 50, imported: true) }
        #expect(DurationStats.minutes(for: t, sessions: old) == 50, "first week: her history gives the estimate")
        let one = old + [session(t, daysAgo: 2, minutes: 70, imported: false)]
        #expect(DurationStats.minutes(for: t, sessions: one) != 70, "one real session is not enough to drop the history")
        let two = one + [session(t, daysAgo: 1, minutes: 70, imported: false)]
        #expect(DurationStats.minutes(for: t, sessions: two) == 70, "then only her real sessions count")
    }

    @Test func aDeloadWeekDoesNotShortenTheUsualDuration() {
        let t = UUID()
        let normal = (1...3).map { session(t, daysAgo: 7 * Double($0) + 20, minutes: 60, imported: false) }
        let deload = session(t, daysAgo: 1, minutes: 35, imported: false)
        let cycle = TrainingCycle(deloadStarts: [deload.startedAt])
        #expect(DurationStats.minutes(for: t, sessions: normal + [deload], cycle: cycle) == 60)
        #expect(DurationStats.minutes(for: t, sessions: normal + [deload]) != 60, "without the cycle the deload drags it down")
    }
}
