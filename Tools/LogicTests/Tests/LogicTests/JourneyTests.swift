import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// « Depuis le début » : strength, scale and attendance, only once there is enough to say.
@Suite(.serialized) struct JourneyTests {
    private let calendar = WeekReview.calendar
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)) ?? .now }
    private func ago(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now) ?? now }
    private let bench = UUID(), gymA = UUID(), gymB = UUID()

    /// One session per `every` days, the weight rising by `step` each time.
    private func sets(_ exercise: UUID, gym: UUID?, sessions: Int, start: Double, step: Double, every: Int = 3) -> [SetLog] {
        (0..<sessions).map { index in
            SetLog(sessionID: UUID(), exerciseID: exercise, gymID: gym, index: 0, weight: start + step * Double(index), reps: 8, completedAt: ago((sessions - 1 - index) * every))
        }
    }

    @Test func strengthComparesTheStartWithNow() {
        let lifts = Journey.measure(sets: sets(bench, gym: gymA, sessions: 10, start: 60, step: 2), names: [bench: "Développé"], eligible: [bench])
        #expect(lifts.count == 1)
        #expect(lifts[0].name == "Développé")
        #expect(lifts[0].fromWeight == 64 && lifts[0].toWeight == 78)
        // Best of the first 3 (64 kg) against the best of the last 3 (78 kg), same reps.
        #expect(abs(lifts[0].change - (78.0 / 64 - 1)) < 0.001)
    }

    @Test func tooFewSessionsOrOtherGymsAreNotCompared() {
        let few = Journey.measure(sets: sets(bench, gym: gymA, sessions: 3, start: 60, step: 2), names: [:], eligible: [bench])
        #expect(few.isEmpty)
        // 4 sessions in one gym + 4 in the other: neither alone is enough, mixing machines would lie.
        let split = sets(bench, gym: gymA, sessions: 3, start: 60, step: 2, every: 6) + sets(bench, gym: gymB, sessions: 3, start: 40, step: 2, every: 6)
        #expect(Journey.measure(sets: split, names: [:], eligible: [bench]).isEmpty)
    }

    @Test func rehabAndOtherIneligibleExercisesAreLeftOut() {
        #expect(Journey.measure(sets: sets(bench, gym: gymA, sessions: 10, start: 60, step: 2), names: [:], eligible: []).isEmpty)
    }

    @Test func hiddenUntilThereIsSomethingToSay() {
        let squat = UUID()
        let all = sets(bench, gym: gymA, sessions: 10, start: 60, step: 2, every: 2) + sets(squat, gym: gymA, sessions: 10, start: 80, step: 2, every: 2)
        let dates = (0..<10).map { ago($0 * 2) }
        func make(_ dates: [Date]) -> Journey? {
            Journey.make(sets: all, sessionDates: dates, names: [:], eligible: [bench, squat], weights: [], weeklyTarget: 4, now: now)
        }
        #expect(make(dates) == nil)                       // 18 days: under 4 weeks
        #expect(make(Array(dates.prefix(5))) == nil)      // under 8 sessions
        let long = (0..<12).map { ago($0 * 3 + 10) } + [ago(0)]
        let journey = make(long)
        #expect(journey != nil)
        #expect((journey?.weeks ?? 0) >= 4)
    }

    @Test func strengthNeedsTwoLifts() {
        let dates = (0..<24).map { ago($0 * 3) }
        let one = Journey.make(sets: sets(bench, gym: gymA, sessions: 10, start: 60, step: 2), sessionDates: dates, names: [:], eligible: [bench], weights: [], weeklyTarget: 4, now: now)
        #expect(one?.strength == nil)
        #expect(one?.measured == 1)
    }

    @Test func freshDataWins() {
        // 30 weeks of an old program at 100 kg, then the last 10 sessions (recent) rising from 60 kg: only the recent ones count.
        let old = (0..<20).map { SetLog(sessionID: UUID(), exerciseID: bench, gymID: gymA, index: 0, weight: 100, reps: 8, completedAt: ago(200 - $0 * 5)) }
        let squat = UUID()
        let recent = sets(bench, gym: gymA, sessions: 10, start: 60, step: 2) + sets(squat, gym: gymA, sessions: 10, start: 80, step: 2)
        let dates = (0..<30).map { ago($0 * 7) }
        let journey = Journey.make(sets: old + recent, sessionDates: dates, names: [:], eligible: [bench, squat], weights: [], weeklyTarget: 4, now: now)
        #expect(journey?.weeks == 12)
        #expect((journey?.strength ?? 0) > 0.15)
    }

    @Test func thisWeekAgainstTheTarget() {
        let weekStart = WeekReview.weekStart(containing: now)
        let past = (0..<24).map { calendar.date(byAdding: .day, value: -(($0 / 3) * 7 + ($0 % 3) + 1), to: weekStart) ?? now }
        let thisWeek = [weekStart.addingTimeInterval(3_600), weekStart.addingTimeInterval(90_000)]
        let journey = Journey.make(sets: [], sessionDates: past + thisWeek, names: [:], eligible: [], weights: [], weeklyTarget: 4, now: now)
        #expect(journey?.thisWeek == 2 && journey?.weeklyTarget == 4)
    }

    @Test func aNewSetupIsNotALossOfStrength() {
        // Real case: the leg press went from 190 kg (total) to 110 kg (new setup), then climbed to 141 kg.
        let weights: [Double] = [160, 180, 180, 190, 110, 113, 127, 134, 141]
        let logs = weights.enumerated().map { index, weight in
            SetLog(sessionID: UUID(), exerciseID: bench, gymID: gymA, index: 0, weight: weight, reps: 10, completedAt: ago((weights.count - index) * 4))
        }
        let lift = Journey.measure(sets: logs, names: [:], eligible: [bench]).first
        #expect(lift?.fromWeight == 113)
        #expect(lift?.toWeight == 141)
        #expect((lift?.change ?? 0) > 0.2)
        #expect(lift?.sessions == 9)
    }

    @Test func weightSinceStartAndRecently() {
        // 8 weeks, a weigh-in every 2 days, linear.
        let days = (0...28).map { HealthService.Day(date: ago(56 - $0 * 2), value: 72 + 1.2 * Double($0) / 28) }
        let total = Journey.weightDelta(days) ?? 0
        #expect(total > 0.9 && total < 1.3)
    }

    @Test func weightNeedsEnoughWeighIns() {
        let sparse = [HealthService.Day(date: ago(40), value: 72), HealthService.Day(date: ago(2), value: 73)]
        #expect(Journey.weightDelta(sparse) == nil)
        let short = (0..<6).map { HealthService.Day(date: ago($0), value: 72) }
        #expect(Journey.weightDelta(short) == nil)
    }
}

/// Today's weight card and this week's off-plan shopping items.
@Suite struct WeightAndNotesTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)
    private func day(_ back: Int, _ kg: Double) -> HealthService.Day { .init(date: now.addingTimeInterval(-Double(back) * 86_400), value: kg) }

    @Test func weightIsTheWeekAverageAndJudgedAgainstTheBulk() {
        let rising = (0...14).map { day(28 - $0 * 2, 72 + Double($0) * 0.04) }   // ≈ +0.14 kg/week
        let status = WeightStatus.make(weights: rising, phase: .bulk, now: now)
        #expect(status?.verdict == .onTrack)
        #expect(abs((status?.average ?? 0) - 72.52) < 0.1)
        let flat = (0...14).map { day(28 - $0 * 2, 72) }
        #expect(WeightStatus.make(weights: flat, phase: .bulk, now: now)?.verdict == .tooSlow)
    }

    @Test func fewWeighInsGiveTheWeightWithoutAVerdict() {
        let status = WeightStatus.make(weights: [day(20, 71), day(1, 72)], phase: .bulk, now: now)
        #expect(status?.average == 72)
        #expect(status?.verdict == nil)
        #expect(WeightStatus.make(weights: [], phase: .bulk, now: now) == nil)
    }

    @Test func freeTextIsSplitWhenTheAIIsAway() {
        let items = ShoppingNotes.split("lessive, 2 éponges\n- 1 L huile d'olive et sopalin")
        #expect(items.map(\.n) == ["Lessive", "Éponges", "Huile d'olive", "Sopalin"])
        #expect(items.map(\.q) == ["", "2", "1 L", ""])
        #expect(ShoppingNotes.split("  ,\n ").isEmpty)
    }

    /// French decimals and « de » : « 1,5 L de lait » is one item, named « Lait ».
    @Test func freeTextKeepsDecimalCommasAndDropsDe() {
        let items = ShoppingNotes.split("1,5 L de lait, 500 g de riz, 2 boîtes d'œufs")
        #expect(items.map(\.n) == ["Lait", "Riz", "Œufs"])
        #expect(items.map(\.q) == ["1,5 L", "500 g", "2 boîtes"])
    }

    /// Typed on Thursday for Saturday's shopping: the cycle flips on Friday 18:00, the item must still be there in store.
    @Test func unboughtExtrasOutliveTheFlip() {
        let thisWeek = PlanCycle.start(for: now), nextWeek = thisWeek.addingTimeInterval(7 * 86_400)
        let lessive = ShoppingNote(emoji: "🧺", name: "Lessive", cycleStart: thisWeek)
        let bought = ShoppingNote(emoji: "🧽", name: "Éponge", cycleStart: thisWeek, checked: true)
        let fresh = ShoppingNote(emoji: "🫒", name: "Huile", cycleStart: nextWeek)
        let notes = [lessive, bought, fresh]
        #expect(ShoppingNotes.visible(notes, cycle: nextWeek).map(\.name) == ["Lessive", "Huile"])
        #expect(ShoppingNotes.stale(notes, cycle: nextWeek).map(\.name) == ["Éponge"])
        #expect(ShoppingNotes.visible(notes, cycle: thisWeek).map(\.name) == ["Lessive", "Éponge"])
    }

    /// « lait, lait » or an AI repeat: one line, and an item already on the list is not added twice.
    @MainActor @Test func extrasAreAddedOnce() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container), cycle = PlanCycle.start(for: now)
        ShoppingNotes.add(ShoppingNotes.split("lait, Lait, sel"), cycle: cycle, in: context)
        ShoppingNotes.add(ShoppingNotes.split("sel"), cycle: cycle, in: context)
        #expect(ShoppingNotes.current(cycle: cycle, in: context).map(\.name).sorted() == ["Lait", "Sel"])
    }

    /// Saturday in store, Thursday's item ticked: it stays on the list struck through (a wrong tap can be undone), gone next cycle.
    @Test func extraTickedAfterTheFlipStaysUntilTheNextCycle() {
        let thisWeek = PlanCycle.start(for: now), nextWeek = thisWeek.addingTimeInterval(7 * 86_400)
        let lessive = ShoppingNote(emoji: "🧺", name: "Lessive", cycleStart: thisWeek)
        ShoppingNotes.toggle(lessive, cycle: nextWeek)
        #expect(lessive.checked)
        #expect(ShoppingNotes.visible([lessive], cycle: nextWeek).map(\.name) == ["Lessive"])
        #expect(ShoppingNotes.stale([lessive], cycle: nextWeek).isEmpty)
        ShoppingNotes.toggle(lessive, cycle: nextWeek)
        #expect(ShoppingNotes.visible([lessive], cycle: nextWeek).map(\.name) == ["Lessive"])
        ShoppingNotes.toggle(lessive, cycle: nextWeek)
        #expect(ShoppingNotes.stale([lessive], cycle: nextWeek.addingTimeInterval(7 * 86_400)).map(\.name) == ["Lessive"])
    }
}
