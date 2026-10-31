import Foundation
import Testing
@testable import HexisLogic

/// Hexis Elle's program file: two sessions that never move, readable by the importer, weekly sets inside its own targets.
@Suite struct ElleProgramTests {
    static let spec: ProgramSpec = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HexisElle/Program.json")
        return try! ProgramImporter.parse(try! Data(contentsOf: url))
    }()

    @Test func twoSessionsNoShortWeek() {
        #expect(Self.spec.workouts.map(\.name) == ["Séance A", "Séance B"])
        #expect((Self.spec.shortWeek ?? []).isEmpty)
        #expect(Self.spec.workouts.allSatisfy { ($0.replaces ?? []).isEmpty })
        #expect(Self.spec.trainingWeeks == 6 && Self.spec.deloadRIR == 3)
    }

    /// Her warmups are the automatic ones, like his (40/70/87 % on the first lift, one feeler set per new muscle, skippable,
    /// following the work weight): her program writes none, since one written ramp would switch the automatic ones off for every other exercise.
    @Test func warmupsAreTheAutomaticOnesLikeHis() {
        let exercises = Self.spec.workouts.flatMap { $0.blocks.flatMap { $0.exercises ?? [] } }
        #expect(exercises.allSatisfy { $0.warmups == nil })
        #expect(exercises.allSatisfy { $0.unit.isEmpty && $0.step > 0 }, "every lift can be warmed up")
        for workout in Self.spec.workouts {
            let inputs = workout.blocks.compactMap { $0.exercises }.map { block in
                WorkoutPlanner.BlockInput(exercises: block.map {
                    WorkoutPlanner.Input(exerciseID: UUID(), name: $0.name, muscle: $0.muscleGroup, sets: $0.sets, repsMin: $0.repsMin, repsMax: $0.repsMax,
                                         rest: $0.rest, targetRIR: $0.rir, step: $0.step)
                })
            }
            let steps = WorkoutPlanner.steps(for: inputs, warmupPercents: WarmupCalculator.defaultPercents)
            let first = inputs[0].exercises[0].exerciseID
            #expect(steps.filter { $0.exerciseID == first && $0.warmupPercent != nil }.count == 3, "\(workout.name): full ramp on the first lift")
            #expect(steps.filter { $0.warmupPercent != nil }.count <= 4, "\(workout.name): full ramp plus at most one feeler set")
        }
    }

    @Test func weeklySetsFitTheTargets() {
        var weekly: [String: Int] = [:]
        for exercise in Self.spec.workouts.flatMap({ $0.blocks.flatMap { $0.exercises ?? [] } }) {
            weekly[exercise.muscleGroup, default: 0] += exercise.sets
        }
        for (muscle, range) in Self.spec.volume ?? [:] where range.count == 2 {
            #expect(range[0]...range[1] ~= weekly[muscle, default: 0], "\(muscle): \(weekly[muscle, default: 0]) sets, target \(range)")
        }
    }
}

/// Rules that follow her program: a 2-session week is never postponed, the first weeks ask for 3 reps in reserve.
@Suite struct ElleRulesTests {
    private let calendar = WeekReview.calendar
    /// Saturday 31 October 2026: one day and a half left in the week.
    private var saturday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 10)) ?? .now }

    @Test func twoSessionsWeekIsNeverPostponed() {
        let a = (id: UUID(), order: 0), b = (id: UUID(), order: 1)
        #expect(WeekPlan.make(templates: [a, b], sessions: [], now: saturday) == nil)
        // A 4-session week at the same point still catches up.
        let four = (0..<4).map { (id: UUID(), order: $0) }
        #expect(WeekPlan.make(templates: four, sessions: [], now: saturday) != nil)
    }

    @Test func rampWeeksAskForTheFloorOfRepsInReserve() {
        let plan = [SessionAdjuster.PlanItem(id: UUID(), name: "Hip thrust", muscle: "Fessiers", rest: 120, step: 2.5)]
        let ramp = SessionAdjuster.compute(plan: plan, sets: [], isDeload: false, isRestart: true, rampRIR: 3, now: saturday)
        #expect(ramp.rirFloor == 3 && ramp.rirDelta == 0)
        let usual = SessionAdjuster.compute(plan: plan, sets: [], isDeload: false, isRestart: true, rampRIR: nil, now: saturday)
        #expect(usual.rirFloor == nil && usual.rirDelta == 1)
    }

    /// Her program spells out 6 training weeks before the deload (his: 5): nothing is due after 5, it is after 6; plateaus bring it
    /// forward 2 weeks at most (week 4 for her, 3 for him), tiredness from week 3.
    @Test func deloadFollowsTheProgramsOwnCadence() {
        let monday = WeekReview.weekStart(containing: saturday, offset: 1)
        func sessions(_ weeks: Int) -> [Date] {
            (1...weeks).map { WeekReview.weekStart(containing: monday, offset: -$0).addingTimeInterval(36_000) }
        }
        func advice(_ weeks: Int, plateaus: Int = 0, due: Int) -> DeloadAdvice? {
            DeloadAdvisor.advice(now: monday, sessionDates: sessions(weeks), deloadStarts: [], plateauCount: plateaus, holidays: [], dueAfterWeeks: due)
        }
        #expect(advice(5, due: 6) == nil)
        #expect(advice(6, due: 6)?.reason.contains("6 semaines") == true)
        #expect(advice(3, plateaus: 2, due: 6) == nil)
        #expect(advice(4, plateaus: 2, due: 6) != nil)
        #expect(advice(3, plateaus: 2, due: 5) != nil)
        #expect(advice(5, due: 5) != nil)
    }

    @Test func deloadWeekAsksForTheProgramsRepsInReserve() {
        let plan = [SessionAdjuster.PlanItem(id: UUID(), name: "Hip thrust", muscle: "Fessiers", rest: 120, step: 2.5)]
        #expect(SessionAdjuster.compute(plan: plan, sets: [], isDeload: true, deloadRIR: 3, now: saturday).rirFloor == 3)
        #expect(SessionAdjuster.compute(plan: plan, sets: [], isDeload: true, deloadRIR: nil, now: saturday).rirFloor == nil)
    }

    @Test func effortReadsAsRepsStillPossible() {
        #expect(EffortScale.simple.map(\.rpe) == [10, 9, 8, 7])
        #expect([10, 9, 8, 7, 5].map(EffortScale.simpleIndex) == [0, 1, 2, 3, 3])
        // Every screen says it her way (never RPE/RIR), his stays the same.
        #expect(EffortScale.target(rir: 2, elle: true) == "reste +2" && EffortScale.target(rir: 2, elle: false) == "RIR 2")
        #expect(EffortScale.average(rpe: 8.4, elle: true) == "reste +1.6" && EffortScale.average(rpe: 8.4, elle: false) == "RPE 8.4")
    }

    /// Her pictures first (woman's figure, her accent), his as a fallback; his app only looks for his.
    @Test func herPicturesComeFirst() {
        #expect(ExerciseImage.assetNames(for: "Développé incliné haltères", elle: true)
            == ["elle-exo-developpe-incline-halteres", "exo-developpe-incline-halteres"])
        #expect(ExerciseImage.assetNames(for: "Leg extension", elle: false) == ["exo-leg-extension"])
    }
}
