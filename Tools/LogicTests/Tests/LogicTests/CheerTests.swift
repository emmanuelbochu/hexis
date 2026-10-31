import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// Encouragement: the right fact at the right moment, and never the same line twice.
@Suite(.serialized) struct CheerTests {
    private let calendar = WeekReview.calendar
    /// Wednesday 28 October 2026, noon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)) ?? .now }
    private func ago(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now) ?? now }

    private func after(_ dates: [Date], target: Int = 4, records: [SessionReview.Record] = [], volume: Double? = nil) -> CheerFact {
        CheerFacts.afterSession(sessionID: UUID(), sessionDates: dates, weeklyTarget: target, records: records, volumeDelta: volume, now: now)
    }

    /// `count` sessions, the last one today, every 2 days.
    private func sessions(_ count: Int) -> [Date] { (0..<count).map { ago($0 * 2) } }

    // MARK: Which fact

    @Test func roundNumberOfSessionsWinsOverEverything() {
        let record = SessionReview.Record(name: "Squat", weight: 100, previous: 95)
        #expect(after(sessions(10), records: [record]).moment == .milestone)
        #expect(after(sessions(25)).moment == .milestone)
        #expect(after(sessions(100)).moment == .milestone)
        #expect(after(sessions(11)).moment != .milestone)
    }

    @Test func recordBeatsTheWeekAndNamesTheBiggestGain() {
        let small = SessionReview.Record(name: "Curl", weight: 20, previous: 19)
        let big = SessionReview.Record(name: "Squat", weight: 110, previous: 100)
        let fact = after(sessions(12), records: [small, big])
        #expect(fact.moment == .record)
        #expect(fact.facts.contains("Squat") && fact.facts.contains("1 autre record"))
    }

    @Test func weekDoneWhenTheTargetIsReachedThisWeek() {
        // Monday, Tuesday and today (Wednesday) = 3 of 3, after an older session.
        let week = WeekReview.weekStart(containing: now)
        let dates = [ago(20), week.addingTimeInterval(3_600), week.addingTimeInterval(90_000), now]
        #expect(after(dates, target: 3).moment == .weekDone)
        #expect(after(dates, target: 4).moment == .regular)
    }

    @Test func comebackAfterAWeekAway() {
        let dates = (0..<12).map { ago(12 + $0 * 2) } + [now]
        let fact = after(dates)
        #expect(fact.moment == .comeback)
        #expect(fact.values["days"] == "12")
    }

    @Test func volumeThenPlainSession() {
        #expect(after(sessions(12), volume: 0.08).moment == .volumeUp)
        #expect(after(sessions(12), volume: 0.02).moment == .regular)
        #expect(after(sessions(12), volume: nil).moment == .regular)
    }

    @Test func everyOccurrenceHasItsOwnKey() {
        #expect(after(sessions(12)).key != after(sessions(12)).key)
        #expect(after(sessions(10)).key == after(sessions(10)).key)
    }

    @Test func homeSpeaksRarely() {
        #expect(CheerFacts.onHome(sessionDates: sessions(12), weeklyTarget: 4, journey: nil, now: now) == nil)
        #expect(CheerFacts.onHome(sessionDates: [], weeklyTarget: 4, journey: nil, now: now) == nil)
        let away = (0..<12).map { ago(7 + $0 * 2) }
        #expect(CheerFacts.onHome(sessionDates: away, weeklyTarget: 4, journey: nil, now: now)?.moment == .comeback)
    }

    @Test func homeWarnsAboutAStreakFromThursday() {
        // 3 full weeks of 4 sessions (Thursday to Sunday), nothing yet this week.
        let weekStart = WeekReview.weekStart(containing: now)
        let weeks = (1...3).flatMap { week in (0..<4).map { calendar.date(byAdding: .day, value: -7 * week + $0 + 3, to: weekStart) ?? now } }
        let thursday = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        #expect(CheerFacts.onHome(sessionDates: weeks, weeklyTarget: 4, journey: nil, now: now)?.moment != .streakAtRisk)
        #expect(CheerFacts.onHome(sessionDates: weeks, weeklyTarget: 4, journey: nil, now: thursday)?.moment == .streakAtRisk)
    }

    @Test func homeCelebratesEachFivePercentOfStrength() {
        let usual = sessions(12)
        func journey(_ strength: Double) -> Journey {
            Journey(weeks: 10, strength: strength, measured: 3, weightChange: nil, thisWeek: 2, weeklyTarget: 4)
        }
        #expect(CheerFacts.onHome(sessionDates: usual, weeklyTarget: 4, journey: journey(0.04), now: now) == nil)
        #expect(CheerFacts.onHome(sessionDates: usual, weeklyTarget: 4, journey: journey(0.12), now: now)?.key == "progress|10")
    }

    // MARK: Never the same twice

    @Test func closeLinesAreRecognised() {
        #expect(Cheer.isTooClose("Record sur le Squat : 100 kg !", used: ["record sur le squat 100 kg"]))
        #expect(Cheer.isTooClose("Séance faite, la régularité paye.", used: ["Séance faite : la régularité paye"]))
        #expect(!Cheer.isTooClose("Développé couché à 82,5 kg, du jamais vu.", used: ["Squat à 100 kg, du jamais vu."]))
        #expect(Cheer.isTooClose("   ", used: []))
    }

    @Test func registerSkipsTheRecentOnes() {
        let recent = Array(Cheer.angles.prefix(7))
        for _ in 0..<50 { #expect(!recent.contains(Cheer.angle(avoiding: recent))) }
    }

    @Test func aRepeatedLineGetsASecondTryThenAHandWrittenOne() async {
        let fact = after(sessions(12))
        var calls = 0
        let result = await Cheer.resolve(fact: fact, used: ["Une séance de plus"], recentAngles: []) { _ in calls += 1; return "Une séance de plus." }
        #expect(calls == 2)
        #expect(result?.angle == nil)
        #expect(result?.text.isEmpty == false)
    }

    @Test func anUnreachableAIIsNotRetried() async {
        var calls = 0
        let result = await Cheer.resolve(fact: after(sessions(12)), used: [], recentAngles: []) { _ in calls += 1; return nil }
        #expect(calls == 1)
        #expect(result?.angle == nil)
    }

    @Test func handWrittenLinesRunOutInsteadOfRepeating() async {
        let fact = after(sessions(12))
        var used: [String] = []
        for _ in 0..<20 {
            guard let line = await Cheer.resolve(fact: fact, used: used, recentAngles: [], generate: { _ in nil }) else { break }
            #expect(!Cheer.isTooClose(line.text, used: used))
            used.append(line.text)
        }
        #expect(!used.isEmpty && used.count < 20)
    }

    @Test func aLongRunNeverRepeatsALine() async throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        var shown: [String] = []
        for index in 0..<60 {
            // No key in tests: the hand-written pool answers, and must stop before it would repeat.
            let fact = after(sessions(12 + index))
            if let line = await Cheer.line(for: fact, in: context) { shown.append(line) }
            if let again = await Cheer.line(for: fact, in: context) { #expect(again == shown.last) }
        }
        #expect(shown.count == Set(shown.map(Cheer.normalized)).count)
        #expect(!shown.isEmpty)
    }

    @Test func homeIsSilentOnceASessionWasDoneToday() async throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        // Back after 9 days: the morning line would say so; once today's session is done it must not stay.
        func done(_ date: Date) {
            let session = WorkoutSession(date: date, gymID: nil, templateID: UUID())
            session.state = .finished
            context.insert(session)
        }
        done(ago(9))
        #expect(await Cheer.home(in: context, now: now.addingTimeInterval(-4 * 3_600)) != nil)
        done(now.addingTimeInterval(-3_600))
        #expect(await Cheer.home(in: context, now: now) == nil)
    }

    @Test func homeAsksOncePerDay() async throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let first = await Cheer.home(in: context, now: now)
        let second = await Cheer.home(in: context, now: now)
        #expect(first == second)
        let markers = try context.fetch(FetchDescriptor<AIInsight>(predicate: #Predicate { $0.kind == "cheerday" }))
        #expect(markers.count == 1)
    }
}
