import Foundation
import Testing
@testable import HexisLogic

/// The few notifications that reach the phone: capped, spaced, never at night, the most useful first, real figures only.
@Suite struct NotificationPolicyTests {
    private let calendar = WeekReview.calendar
    /// Wednesday 28 October 2026, noon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)) ?? .now }
    private func at(_ days: Int, hour: Int = 17, minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
    private func notice(_ kind: Notice.Kind, _ date: Date) -> Notice { Notice(kind: kind, date: date, title: "t", body: "b") }

    @Test func nothingAtNightNorInThePast() {
        let kept = NotificationPolicy.apply([notice(.absence, at(1, hour: 23)), notice(.absence, at(1, hour: 7)), notice(.absence, at(-1)), notice(.absence, at(2))], now: now)
        #expect(kept.map(\.date) == [at(2)])
    }

    @Test func oneADayAndTwentyHoursApartTheMostUsefulWins() {
        let kept = NotificationPolicy.apply([notice(.absence, at(1, hour: 10)), notice(.review, at(1, hour: 18)), notice(.absence, at(2, hour: 9))], now: now)
        #expect(kept.map(\.kind) == [.review])
    }

    @Test func atMostThreeAWeek() {
        let days = [1, 3, 5, 7].map { notice(.absence, at($0)) }
        let kept = NotificationPolicy.apply(days, now: now)
        // Thursday (+1), Saturday (+3), Monday (+5, next week), Wednesday (+7): the week of the 28th holds two, the next two.
        #expect(kept.count == 4)
        let sameWeek = (1...5).map { notice(.absence, at(0, hour: 9 + $0 * 2)) }
        #expect(NotificationPolicy.apply(sameWeek, now: now.addingTimeInterval(-3600)).count <= 1)
        let spread = [1, 2, 3, 4, 5].map { notice(.absence, at($0)) }
        #expect(NotificationPolicy.apply(spread, now: now).count <= 2 * NotificationPolicy.maxPerWeek)
    }

    @Test func idsStartWithThePrefixSoTheHubOwnsThem() {
        #expect(notice(.review, at(1)).id.hasPrefix(NotificationPolicy.prefix))
    }
}

@Suite struct PerfNoticesTests {
    private let calendar = WeekReview.calendar
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)) ?? .now }

    private func week(sessions: Int, volume: Double, records: [SessionReview.Record] = []) -> WeekReview {
        var review = WeekReview(start: WeekReview.weekStart(containing: now), sessions: [], sets: [], exercises: [:])
        review.sessionCount = sessions
        review.volume = volume
        review.records = records
        return review
    }

    private func snapshot(this: WeekReview?, previous: WeekReview? = nil, deload: Date? = nil) -> PerfNotices.Snapshot {
        PerfNotices.Snapshot(now: now, sessionDates: [now.addingTimeInterval(-86_400)], weeklyTarget: 4, thisWeek: this, previousWeek: previous, deloadWeekStart: deload)
    }

    @Test func noReviewWithoutASession() {
        #expect(PerfNotices.review(snapshot(this: week(sessions: 0, volume: 0)), calendar: calendar) == nil)
        #expect(PerfNotices.review(snapshot(this: nil), calendar: calendar) == nil)
    }

    @Test func theReviewGivesRealFiguresOnSundayEvening() throws {
        let record = SessionReview.Record(name: "Squat", weight: 120)
        let notice = try #require(PerfNotices.review(snapshot(this: week(sessions: 2, volume: 9000, records: [record]), previous: week(sessions: 4, volume: 20000)), calendar: calendar))
        #expect(calendar.component(.weekday, from: notice.date) == 1 && calendar.component(.hour, from: notice.date) == 18)
        #expect(notice.body == "2/4 séances · 1 record (Squat 120 kg)")
    }

    @Test func aChangeOfVolumeIsOnlyToldOnACompleteWeekAndWhenItIsBig() throws {
        let previous = week(sessions: 4, volume: 20000)
        let big = try #require(PerfNotices.review(snapshot(this: week(sessions: 4, volume: 22400), previous: previous), calendar: calendar))
        #expect(big.body.contains("volume +12 %"))
        let small = try #require(PerfNotices.review(snapshot(this: week(sessions: 4, volume: 20400), previous: previous), calendar: calendar))
        #expect(!small.body.contains("volume"))
    }

    @Test func aLighterWeekNextIsAnnouncedInTheSameMessage() throws {
        let next = WeekReview.weekStart(containing: now, offset: 1)
        let notice = try #require(PerfNotices.review(snapshot(this: week(sessions: 3, volume: 1), deload: next), calendar: calendar))
        #expect(notice.body.hasSuffix("Semaine allégée demain : moitié des séries, mêmes charges."))
    }
}
