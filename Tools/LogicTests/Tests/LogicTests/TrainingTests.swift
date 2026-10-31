import Foundation
import SwiftData
import Testing
@testable import HexisLogic

private let base = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 18))!

/// One session of an exercise: `reps` at 50 kg, the sets `gaps` seconds apart (the first gap is before the 2nd set).
private func session(_ exercise: UUID, day: Int, reps: [Int], gaps: [TimeInterval]) -> [SetLog] {
    let id = UUID()
    var time = base.addingTimeInterval(Double(day) * 86_400)
    return reps.enumerated().map { i, count in
        if i > 0 { time = time.addingTimeInterval(gaps[i - 1]) }
        return SetLog(sessionID: id, exerciseID: exercise, gymID: nil, index: i, weight: 50, reps: count, completedAt: time)
    }
}

/// A rest whose session screen is gone (session abandoned from Home, or closed) never rings.
@Suite struct RestTimerTests {
    @MainActor @Test func aRestOfAGoneSessionDoesNotRing() async throws {
        var rings = 0
        var timer: RestTimer? = RestTimer { rings += 1 }
        timer?.start(seconds: 1)
        timer = nil
        let kept = RestTimer { rings += 10 }
        kept.start(seconds: 1)
        // Wait until the kept one is over (the main actor may be busy with the simulated lives; woken > 3 s late it stays silent).
        for _ in 0..<1200 where kept.isRunning { try await Task.sleep(for: .seconds(0.1)) }
        try await Task.sleep(for: .seconds(0.3))
        #expect(rings % 10 == 0, "le repos d'une séance disparue a sonné")
        #expect(timer == nil && !kept.isRunning)
    }
}

@Suite struct RestTests {
    let id = UUID()
    func item(rest: Int = 90, alone: Bool = true, repsMax: Int = 12) -> SessionAdjuster.PlanItem {
        .init(id: id, name: "Test", rest: rest, step: 2.5, alone: alone)
            .with { $0.repsMin = 8; $0.repsMax = repsMax }
    }
    /// Three sessions, rest taken ≈ gap − 35 s (a set of 8-12 reps).
    func sets(reps: [Int], gaps: [TimeInterval]) -> [SetLog] {
        (0..<3).flatMap { session(id, day: $0 * 3, reps: reps, gaps: gaps) }
    }

    @Test func fewRepsLostShortensTowardTheRestTaken() {
        let result = SessionAdjuster.compute(plan: [item()], sets: sets(reps: [10, 10, 10, 9], gaps: [130, 140, 125]), isDeload: false, now: base.addingTimeInterval(20 * 86_400))
        #expect(result.restDelta[id] == -15)
    }

    @Test func aBigLossNeverGivesLessThanPrescribed() {
        // Rests of about 60 s with 30 % of the reps lost: the answer is the prescribed 90 s, not 75.
        let result = SessionAdjuster.compute(plan: [item()], sets: sets(reps: [10, 9, 8, 7], gaps: [95, 100, 90]), isDeload: false, now: base.addingTimeInterval(20 * 86_400))
        #expect(result.restDelta[id] == nil)
    }

    @Test func aBigLossAfterAShortPrescriptionAddsAStepUpToTheCap() {
        // Prescribed 75 s but about 90 s taken with 30 % lost: +15 s on what is taken, capped at 90 s.
        let result = SessionAdjuster.compute(plan: [item(rest: 75)], sets: sets(reps: [10, 9, 8, 7], gaps: [130, 140, 125]), isDeload: false, now: base.addingTimeInterval(20 * 86_400))
        #expect(result.restDelta[id] == 15)
    }

    @Test func supersetsAreLeftAlone() {
        let result = SessionAdjuster.compute(plan: [item(alone: false)], sets: sets(reps: [10, 10, 10, 9], gaps: [130, 140, 125]), isDeload: false, now: base.addingTimeInterval(20 * 86_400))
        #expect(result.restDelta.isEmpty)
    }

    @Test func handTypedTimesProveNothing() {
        let even = (0..<3).flatMap { session(id, day: $0 * 3, reps: [10, 10, 10, 9], gaps: [120, 120, 120]) }
        let result = SessionAdjuster.compute(plan: [item()], sets: even, isDeload: false, now: base.addingTimeInterval(20 * 86_400))
        #expect(result.restDelta.isEmpty)
    }

    @Test func neverUnderTheFloor() {
        // Very short rests and no loss: the target stops at 60 s (90 s for heavy work).
        let quick = SessionAdjuster.compute(plan: [item(rest: 75)], sets: sets(reps: [10, 10, 10, 10], gaps: [75, 80, 70]), isDeload: false, now: base.addingTimeInterval(20 * 86_400))
        #expect(quick.restDelta[id] == -15)
        let heavy = SessionAdjuster.compute(plan: [item(rest: 120, repsMax: 6)], sets: sets(reps: [6, 6, 6, 6], gaps: [75, 80, 70]), isDeload: false, now: base.addingTimeInterval(20 * 86_400))
        #expect(heavy.restDelta[id] == -30)
    }
}

private extension SessionAdjuster.PlanItem {
    func with(_ change: (inout Self) -> Void) -> Self { var copy = self; change(&copy); return copy }
}

@Suite struct WarmupTests {
    private func input(_ muscle: String, repsMax: Int = 8, sets: Int = 3) -> WorkoutPlanner.Input {
        .init(exerciseID: UUID(), name: muscle, muscle: muscle, sets: sets, repsMin: 5, repsMax: repsMax, rest: 90, targetRIR: 1, step: 2.5)
    }
    private func warmups(_ steps: [WorkoutStep]) -> [UUID: Int] {
        Dictionary(grouping: steps.filter { $0.warmupPercent != nil }, by: \.exerciseID).mapValues(\.count)
    }

    @Test func fullRampOnlyOnTheFirstLiftAndOneFeelerForTheOtherRegion() {
        let press = input("Épaules"), row = input("Dos"), squat = input("Quadriceps"), curl = input("Ischios")
        let steps = WorkoutPlanner.steps(for: [.init(exercises: [press]), .init(exercises: [row]), .init(exercises: [squat]), .init(exercises: [curl])], warmupPercents: WarmupCalculator.defaultPercents)
        let counts = warmups(steps)
        #expect(counts[press.exerciseID] == 3)
        #expect(counts[row.exerciseID] == nil)   // upper body already warm: nothing
        #expect(counts[squat.exerciseID] == 1)   // first lower-body lift: one feeler set
        #expect(counts[curl.exerciseID] == nil)
    }

    /// Her program writes its ramps (A1: 3, A2: 2) and none elsewhere: exactly those, at the written % and reps.
    @Test func writtenRampsAreFollowedAndTheOthersGetNone() {
        var thrust = input("Fessiers"), squat = input("Quadriceps"), curl = input("Ischios")
        thrust.warmups = [(0.3, 10), (0.5, 6), (0.75, 3)]
        squat.warmups = [(0.5, 6), (0.75, 3)]
        curl.warmups = []
        let steps = WorkoutPlanner.steps(for: [.init(exercises: [thrust]), .init(exercises: [squat]), .init(exercises: [curl])], warmupPercents: WarmupCalculator.defaultPercents)
        let counts = warmups(steps)
        #expect(counts[thrust.exerciseID] == 3 && counts[squat.exerciseID] == 2 && counts[curl.exerciseID] == nil)
        let ramp = steps.filter { $0.exerciseID == squat.exerciseID && $0.warmupPercent != nil }
        #expect(ramp.map(\.warmupPercent) == [0.5, 0.75] && ramp.map(\.repsMax) == [6, 3])
    }

    @Test func aLightSupersetDoesNotWarmTheRegionForLater() {
        let squat = input("Quadriceps"), curl = input("Biceps", repsMax: 12), triceps = input("Triceps", repsMax: 12), bench = input("Pectoraux")
        let steps = WorkoutPlanner.steps(for: [.init(exercises: [squat]), .init(exercises: [curl, triceps]), .init(exercises: [bench])], warmupPercents: WarmupCalculator.defaultPercents)
        #expect(warmups(steps)[bench.exerciseID] == 1)
    }

    @Test func warmupRestsAreShort() {
        let steps = WorkoutPlanner.steps(for: [.init(exercises: [input("Dos")])], warmupPercents: WarmupCalculator.defaultPercents)
        #expect(steps.filter { $0.warmupPercent != nil }.map(\.restAfter) == [30, 45, 60])
    }

    @Test func supersetRestComesOnlyAfterTheLastExercise() {
        let a = input("Biceps", repsMax: 12, sets: 3), b = input("Triceps", repsMax: 12, sets: 3)
        let work = WorkoutPlanner.steps(for: [.init(exercises: [a, b])], warmupPercents: []).filter { $0.warmupPercent == nil }
        #expect(work.count == 6)
        #expect(work.filter { $0.exerciseID == a.exerciseID }.dropLast(0).allSatisfy { $0.restAfter == 0 })
        #expect(work.dropLast().filter { $0.exerciseID == b.exerciseID }.allSatisfy { $0.restAfter == 90 })
        #expect(work.last?.restAfter == 0)
    }
}

/// Checks the program file itself against its own volume targets and the 11-set session rule.
@Suite struct ProgramFileTests {
    static let spec: ProgramSpec = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Hexis/Resources/Program.json")
        return try! ProgramImporter.parse(try! Data(contentsOf: url))
    }()

    @Test func weeklySetsFitTheTargets() {
        var weekly: [String: Int] = [:]
        for workout in Self.spec.workouts where (workout.replaces ?? []).isEmpty {
            for exercise in workout.blocks.flatMap({ $0.exercises ?? [] }) where exercise.unit.isEmpty && exercise.muscleGroup != "Cardio" {
                weekly[exercise.muscleGroup, default: 0] += exercise.sets
            }
        }
        for (muscle, range) in Self.spec.volume ?? [:] where range.count == 2 {
            let sets = weekly[muscle] ?? 0
            #expect(sets >= range[0] && sets <= range[1], "\(muscle): \(sets) séries/semaine, cible \(range[0])–\(range[1])")
        }
    }

    @Test func noMuscleOverElevenSetsInASession() {
        for workout in Self.spec.workouts {
            var perMuscle: [String: Int] = [:]
            for exercise in workout.blocks.flatMap({ $0.exercises ?? [] }) { perMuscle[exercise.muscleGroup, default: 0] += exercise.sets }
            for (muscle, sets) in perMuscle { #expect(sets <= 11, "\(workout.name) : \(muscle) \(sets) séries") }
        }
    }

    @Test func restsAreSane() {
        for workout in Self.spec.workouts {
            for block in workout.blocks {
                let exercises = block.exercises ?? []
                for exercise in exercises where exercise.unit.isEmpty {
                    #expect(exercise.rest >= 60 && exercise.rest <= 150, "\(workout.name) / \(exercise.name) : repos \(exercise.rest) s")
                    #expect(exercise.repsMin <= exercise.repsMax && exercise.sets >= 1)
                }
                // Both exercises of a superset rest together: they should be prescribed the same rest.
                if exercises.count > 1 { #expect(Set(exercises.map(\.rest)).count == 1, "\(workout.name) : superset à repos différents \(exercises.map(\.name))") }
            }
        }
    }

    @Test func sessionLengthStaysShort() {
        // Per set: ~35 s of work, then the rest (a superset shares its rest between both exercises). Warmups not counted.
        for workout in Self.spec.workouts {
            var seconds = 0
            for block in workout.blocks {
                let exercises = block.exercises ?? []
                guard !exercises.isEmpty else { continue }
                if exercises.count == 1, let e = exercises.first { seconds += e.sets * (35 + e.rest) } else {
                    let rounds = exercises.map(\.sets).max() ?? 0
                    seconds += rounds * (35 * exercises.count + (exercises.last?.rest ?? 0))
                }
            }
            #expect(seconds / 60 <= 75, "\(workout.name) : ~\(seconds / 60) min de travail et repos, sans échauffements")
        }
    }
}

/// The program file explains every exercise and its rehab slots exist; renames and name guesses keep the history right.
@Suite struct ProgramContentTests {
    @Test func everyExerciseSaysWhyHowAndWhere() {
        let all = ProgramFileTests.spec.workouts.flatMap { $0.blocks.flatMap { $0.exercises ?? [] } }
            + (ProgramFileTests.spec.rehab?.phases.flatMap { $0.values.flatMap { $0 } } ?? [])
        for e in all {
            #expect(!e.cue.isEmpty && !e.target.isEmpty, "\(e.name) : consigne ou muscles manquants")
            for label in ["Pourquoi : ", "Réglage : ", "Mouvement : "] {
                #expect(e.points.contains { $0.hasPrefix(label) }, "\(e.name) : point « \(label)» manquant")
            }
        }
    }

    @Test func everyRehabSlotIsFilledInEveryPhase() {
        let slots = Set(ProgramFileTests.spec.workouts.flatMap { $0.blocks.compactMap(\.rehab) })
        #expect(!slots.isEmpty)
        for (i, phase) in (ProgramFileTests.spec.rehab?.phases ?? []).enumerated() {
            for slot in slots { #expect(!(phase[slot] ?? []).isEmpty, "phase \(i + 1) : créneau \(slot) vide") }
        }
    }

    @MainActor @Test func aRenamedExerciseKeepsItsRecord() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let old = Exercise(name: "Curl haltères incliné 60°", muscleGroup: "Biceps")
        context.insert(old)
        let json = #"{"name":"P","workouts":[{"name":"A","blocks":[{"exercises":[{"name":"Curl incliné haltères","renamedFrom":"Curl haltères incliné 60°","muscleGroup":"Biceps"}]}]}]}"#
        try ProgramImporter.insert(try ProgramImporter.parse(Data(json.utf8)), into: context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
        #expect(exercises.first?.id == old.id && exercises.first?.name == "Curl incliné haltères")
    }

    #if !ELLE  // his program's rehab
    @MainActor @Test func rehabWeeksDoneWithAnOlderRehabStillCount() throws {
        ProgramCatalog.fileURL = LifeSimulator.appProgramFile
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let retired = Exercise(name: "Isométrie mollets assis", muscleGroup: "Réhab")
        context.insert(retired)
        // Two clean weeks of 2 sessions with an exercise the file no longer has (base = Thursday 2026-10-01).
        for day in [-3, -1, 4, 6] { session(retired.id, day: day, reps: [45], gaps: []).forEach(context.insert) }
        let now = base.addingTimeInterval(12 * 86_400)
        #expect(Rehab.load(context: context, now: now)?.week == 3)
    }

    #endif

    @MainActor @Test func endingASessionWithoutAnySetLeavesNoEmptySession() throws {
        ProgramCatalog.fileURL = LifeSimulator.appProgramFile
        for key in ["programFileHash", "programStructureHash", ProgramSync.startKey] { UserDefaults.standard.removeObject(forKey: key) }
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        ProgramSync.sync(in: context)
        let template = try #require(try context.fetch(FetchDescriptor<Program>()).first?.templates.first)
        let session = WorkoutSession(date: .now, gymID: nil, templateID: template.id)
        context.insert(session)
        let vm = WorkoutViewModel(session: session, template: template, context: context)
        vm.finish()
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }

    /// A day marked « Fatigué » (lighter on purpose) is not the reference of the next session: the one before it is.
    @MainActor @Test func aTiredDayIsNotTheNextGoal() throws {
        ProgramCatalog.fileURL = LifeSimulator.appProgramFile
        for key in ["programFileHash", "programStructureHash", ProgramSync.startKey] { UserDefaults.standard.removeObject(forKey: key) }
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        ProgramSync.sync(in: context)
        let names = Dictionary(try context.fetch(FetchDescriptor<Exercise>()).map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let rehab = Set(ProgramCatalog.rehabExercises.map(\.name))
        let template = try #require(try context.fetch(FetchDescriptor<Program>()).first?.templates.sorted { $0.order < $1.order }.first)
        // A plain loaded exercise (not a rehab slot, not a duration).
        let exercise = try #require(template.blocks.sorted { $0.order < $1.order }.flatMap(\.exercises)
            .first { !rehab.contains(names[$0.exerciseID] ?? "") && $0.progressionStep > 0 && $0.restSeconds > 0 })
        func done(daysAgo: Double, weight: Double, reps: Int, tired: Bool) {
            let date = Date.now.addingTimeInterval(-daysAgo * 86_400)
            let session = WorkoutSession(date: date, gymID: nil, templateID: template.id)
            session.state = .finished
            session.endedAt = date.addingTimeInterval(3600)
            context.insert(session)
            for i in 0..<3 {
                context.insert(SetLog(sessionID: session.id, exerciseID: exercise.exerciseID, gymID: nil, index: i, weight: weight, reps: reps, completedAt: date.addingTimeInterval(Double(i) * 180)))
            }
            if tired { context.insert(ExerciseFeeling(sessionID: session.id, exerciseID: session.id, feeling: .tired)) }
        }
        done(daysAgo: 8, weight: 60, reps: 8, tired: false)
        done(daysAgo: 3, weight: 45, reps: 6, tired: true)
        try context.save()
        let session = WorkoutSession(date: .now, gymID: nil, templateID: template.id)
        context.insert(session)
        let vm = WorkoutViewModel(session: session, template: template, context: context)
        let first = try #require(vm.steps.indices.first { vm.steps[$0].exerciseID == exercise.exerciseID && vm.steps[$0].warmupPercent == nil })
        #expect((vm.values[first]?.weight ?? 0) >= 60)
    }

    /// Bug of 30 Oct (her first session ever): with no history every weight is 0, so the warmups were hidden for good and typing the
    /// first work weight did not bring them back. They come back once the weight is typed, unless she skipped them herself.
    #if !ELLE  // her lifts all have a starting weight: their warmups show from the start (StartWeightTests)
    @MainActor @Test func warmupsAppearOnceTheFirstWeightIsTyped() throws {
        ProgramCatalog.fileURL = LifeSimulator.appProgramFile
        for key in ["programFileHash", "programStructureHash", ProgramSync.startKey] { UserDefaults.standard.removeObject(forKey: key) }
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        ProgramSync.sync(in: context)
        let template = try #require(try context.fetch(FetchDescriptor<Program>()).first?.templates.sorted { $0.order < $1.order }.first)
        let session = WorkoutSession(date: .now, gymID: nil, templateID: template.id)
        context.insert(session)
        let vm = WorkoutViewModel(session: session, template: template, context: context)
        let warm = try #require(vm.steps.indices.first { vm.steps[$0].warmupPercent != nil })
        let id = vm.steps[warm].exerciseID
        let work = try #require(vm.steps.indices.first { vm.steps[$0].exerciseID == id && vm.steps[$0].warmupPercent == nil })
        let group = try #require(vm.groups.first { $0.exerciseID == id })
        #expect(!vm.hasPendingWarmups(group), "no history: nothing to ramp to yet")
        vm.setWeight(work, 60)
        #expect(vm.hasPendingWarmups(group) && vm.visibleRows(group).contains(warm))
        #expect((vm.values[warm]?.weight ?? 0) > 0 && (vm.values[warm]?.weight ?? 0) < 60)
        // Skipped on purpose, then the weight changes: they stay hidden.
        vm.skipWarmups(of: group)
        vm.setWeight(work, 65)
        #expect(!vm.hasPendingWarmups(group))
    }
    #endif

    @Test func rehabNamesAreNotTakenForABarbell() {
        #expect(LoadProfile.guess(name: "Squat 1 jambe tenu") == .total)
        #expect(LoadProfile.guess(name: "Montée de marche en poussée") == .total)
        // The real exercises of both programs, as typed at the gym.
        #expect(LoadProfile.guess(name: "Hip thrust machine") == .total, "selectorized: the machine's number, not per side")
        #expect(LoadProfile.guess(name: "Rowing machine") == .plateMachine)
        #expect(LoadProfile.guess(name: "Rowing machine") == .plateMachine)
        #expect(LoadProfile.guess(name: "Abduction machine") == .stack)
        #expect(LoadProfile.guess(name: "Oiseau machine") == .stack)
        #expect(LoadProfile.guess(name: "Curl marteau") == .dumbbells)
        #expect(LoadProfile.guess(name: "Neck flexion") == .total)
        #expect(LoadProfile.guess(name: "Fente bulgare Smith") == .plateMachine)
        #expect(LoadProfile.guess(name: "Squat Smith") == .plateMachine)
        #expect(ExerciseVisual.guess(name: "Skull crusher haltères").muscle == .triceps)
        #expect(ExerciseVisual.guess(name: "Squat 1 jambe tenu au point").equipment == .bodyweight)
    }
}

/// The week switches by itself to the 3-session variant when it can no longer hold the usual 4 (one every other day).
@Suite struct WeekRotationTests {
    let templates: [WeekRotation.Template] = [
        .init(id: UUID(), order: 0, name: "Lower A"), .init(id: UUID(), order: 1, name: "Upper A"),
        .init(id: UUID(), order: 2, name: "Lower B"), .init(id: UUID(), order: 3, name: "Upper B"),
        .init(id: UUID(), order: 4, name: "Full A", replaces: ["Lower A", "Lower B"]),
        .init(id: UUID(), order: 5, name: "Upper A · 3 j", replaces: ["Upper A"]),
    ]
    let short = ["Full A", "Upper A · 3 j", "Upper B"]

    /// Day 0 = Monday 2026-10-26, 18:00.
    func day(_ n: Int) -> Date {
        WeekReview.calendar.date(from: DateComponents(year: 2026, month: 10, day: 26 + n, hour: 18)) ?? .now
    }

    func id(_ name: String) -> UUID? { templates.first { $0.name == name }?.id }

    func rotation(_ done: [(String, Int)], on today: Int) -> WeekRotation {
        let past: [(templateID: UUID?, date: Date)] = [(id("Upper B"), day(-2))]
        return WeekRotation.make(templates: templates, shortWeek: short, sessions: past + done.map { (id($0.0), day($0.1)) }, now: day(today))
    }

    @Test func aUsualWeekKeepsTheProgramOrder() {
        #expect(rotation([], on: 0) == WeekRotation(next: id("Lower A"), short: false, remaining: []))
        #expect(rotation([("Lower A", 0), ("Upper A", 1)], on: 3).next == id("Lower B"))
        #expect(rotation([("Lower A", 0), ("Upper A", 1), ("Lower B", 3)], on: 5).next == id("Upper B"))
    }

    @Test func mondayThenThursdayBecomesAThreeSessionWeek() {
        let r = rotation([("Lower A", 0)], on: 3)
        #expect(r.short && r.next == id("Upper A · 3 j") && r.remaining == ["Upper A · 3 j", "Upper B"])
        #expect(rotation([("Lower A", 0), ("Upper A · 3 j", 3)], on: 5).next == id("Upper B"))
    }

    @Test func aLateStartBeginsWithTheFullBodySession() {
        #expect(rotation([], on: 2).next == id("Full A"))
        // Once a 3-session-only session is done, the week stays short even if it could hold more.
        let after = rotation([("Full A", 2)], on: 3)
        #expect(after.short && after.next == id("Upper A · 3 j"))
    }

    /// Real week of 2026-10-26: Lower A on Monday and again on Thursday, Home opened Thursday 21:57.
    @Test func lowerATwiceThenThursdayNight() {
        let thursdayNight = WeekReview.calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 21, minute: 57)) ?? .now
        let thursdayMorning = WeekReview.calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 11)) ?? .now
        let r = WeekRotation.make(templates: templates, shortWeek: short, sessions: [(id("Lower A"), day(0)), (id("Lower A"), thursdayMorning)], now: thursdayNight)
        #expect(!r.short && r.next == id("Upper A"))
    }

    @Test func saturdayAfterTwoUsualSessionsGoesToUpperB() {
        #expect(rotation([("Lower A", 0), ("Upper A", 1)], on: 5).next == id("Upper B"))
    }

    @Test func theWeekAfterAShortOneStartsTheUsualOrderAgain() {
        let past: [(templateID: UUID?, date: Date)] = [(id("Full A"), day(-4)), (id("Upper A · 3 j"), day(-3)), (id("Upper B"), day(-2))]
        let r = WeekRotation.make(templates: templates, shortWeek: short, sessions: past, now: day(0))
        #expect(!r.short && r.next == id("Lower A"))
    }

    @Test func theShortWeekKeepsThePriorityVolume() {
        let spec = ProgramFileTests.spec
        var weekly: [String: Int] = [:]
        for name in spec.shortWeek ?? [] {
            for e in spec.workouts.first(where: { $0.name == name })?.blocks.flatMap({ $0.exercises ?? [] }) ?? [] { weekly[e.muscleGroup, default: 0] += e.sets }
        }
        for muscle in spec.priorities ?? [] {
            #expect((weekly[muscle] ?? 0) >= (spec.volume?[muscle]?.first ?? 0), "\(muscle) : \(weekly[muscle] ?? 0) séries en semaine à 3")
        }
    }
}

@Suite struct TypoTests {
    /// Found by the deep chase (31 Oct): 18 kg at 9/9/7 reps on a 10–15 range restarts lower, and the plateau note's −1 kg came on top
    /// then snapped down to 14 kg (−22 %). One cut at a time.
    @Test func aPlateauCutIsNotStackedOnAGoalAlreadyLowered() throws {
        let last: [(weight: Double, reps: Int)] = [(18, 9), (18, 9), (18, 7)]
        let base = try #require(Progression.target(lastSets: last, repsMin: 10, repsMax: 15, step: 1, averageRPE: nil, targetRPE: 7))
        #expect(base.weight < 18)
        #expect(Progression.shifted(base, by: -1, heaviest: 18, step: 1).weight == base.weight)
        let held = Progression.Target(weight: 18, reps: 10, increased: false)
        #expect(Progression.shifted(held, by: -1, heaviest: 18, step: 1).weight == 17)
        #expect(Progression.shifted(held, by: 1, heaviest: 18, step: 1).weight == 19)
    }

    @Test func anExtraZeroNeverBecomesTheNextGoal() {
        let target = Progression.target(lastSets: [(80, 10), (80, 10), (800, 10)], repsMin: 8, repsMax: 12, step: 2.5)
        #expect(target?.weight == 80)
        #expect(Progression.hold(lastSets: [(80, 10), (800, 9)], repsMin: 8, repsMax: 12)?.weight == 80)
    }

    @Test func aPlateauNeverCutsAPercentageOfATypo() {
        let id = UUID(), session = UUID()
        func set(_ weight: Double, _ index: Int) -> SetLog { SetLog(sessionID: session, exerciseID: id, gymID: nil, index: index, weight: weight, reps: 10) }
        #expect(SessionAdjuster.topWeight([set(35, 0), set(35, 1), set(350, 2)]) == 35, "35 / 35 / 350: the 5 % cut starts from 35, not 350")
        #expect(SessionAdjuster.topWeight([set(60, 0), set(70, 1), set(80, 2)]) == 80, "a real pyramid keeps its top")
    }

    @Test func aRealPyramidIsKept() {
        #expect(Progression.hold(lastSets: [(60, 10), (70, 8), (80, 6)], repsMin: 6, repsMax: 10)?.weight == 80)
    }
}

@Suite struct StartWeightTests {
    @Test func noHistoryKeepsTheProgramsStart() {
        #expect(StartWeight.scale([]) == 1)
        #expect(StartWeight.weight(start: 50, scale: 1, step: 2.5) == 50)
    }

    @Test func scalesWithWhatWasReallyLifted() {
        // Hip thrust 60 instead of 50, curl 20 instead of 25: the median of ×1.2 and ×0.8 is ×1.
        #expect(StartWeight.scale([(60, 50), (20, 25)]) == 1.0)
        #expect(abs(StartWeight.scale([(60, 50)]) - 1.2) < 1e-9)
        #expect(StartWeight.weight(start: 20, scale: 1.2, step: 2.5) == 22.5)  // 24 rounded DOWN to the step
    }

    @Test func oneOddLiftCannotThrowItOff() {
        #expect(StartWeight.scale([(500, 50)]) == 2.5)
        #expect(StartWeight.scale([(1, 50)]) == 0.5)
        #expect(StartWeight.scale([(0, 50), (.nan, 50), (40, 0)]) == 1)
        // Three lifts, one odd: the median ignores it.
        #expect(abs(StartWeight.scale([(60, 50), (30, 25), (200, 20)]) - 1.2) < 1e-9)
    }

    @Test func neverBelowOneStep() {
        #expect(StartWeight.weight(start: 3, scale: 0.5, step: 1) == 1)
        #expect(StartWeight.weight(start: 0, scale: 1, step: 1) == 0)
    }

    #if ELLE
    /// Her first session ever: every lift has a weight to aim at, so the warmups show from the first set.
    @MainActor @Test func herFirstSessionStartsFromHerWeights() throws {
        ProgramCatalog.fileURL = LifeSimulator.appProgramFile
        for key in ["programFileHash", "programStructureHash", ProgramSync.startKey] { UserDefaults.standard.removeObject(forKey: key) }
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        ProgramSync.sync(in: context)
        for template in try context.fetch(FetchDescriptor<Program>()).first?.templates ?? [] {
            let session = WorkoutSession(date: .now, gymID: nil, templateID: template.id)
            context.insert(session)
            let vm = WorkoutViewModel(session: session, template: template, context: context)
            let work = vm.steps.indices.filter { vm.steps[$0].warmupPercent == nil }
            #expect(work.allSatisfy { (vm.values[$0]?.weight ?? 0) > 0 }, "\(template.id): a weight to aim at on every lift")
            let first = try #require(vm.groups.first)
            #expect(vm.hasPendingWarmups(first), "the first lift shows its warmup at once")
            if let thrust = vm.steps.indices.first(where: { vm.steps[$0].name == "Hip thrust machine" && vm.steps[$0].warmupPercent == nil }) {
                #expect((vm.values[thrust]?.weight ?? 0) >= 50, "her hip thrust: the machine's weight (50 in Hevy), never halved")
            }
        }
    }
    #endif
}
