import Foundation
import Testing
@testable import HexisLogic

/// What a screen may show on each day of the week (the bugs a pure-logic test misses: a figure that is right but absurd at that moment).
@Suite struct ScreenSanityTests {
    private let calendar = WeekReview.calendar
    private let monday = WeekReview.weekStart(containing: Date(timeIntervalSince1970: 1_793_000_000))

    private func week() -> WeekReview { WeekReview(start: monday, sessions: [], sets: [], exercises: [:]) }

    @Test func weekComparisonAppearsOnlyOnceTheWeekIsOver() {
        let review = week()
        for day in 0..<7 {
            for hour in [0, 12, 23] {
                let now = calendar.date(byAdding: .hour, value: day * 24 + hour, to: monday) ?? monday
                #expect(!review.isOver(now: now), "day \(day) \(hour) h: the week still runs (Sunday included)")
                #expect(WeekReview.change(17, vs: 100, weekIsOver: review.isOver(now: now)) == nil, "no « -83 % » mid-week")
            }
        }
        let next = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        #expect(review.isOver(now: next))
        #expect(WeekReview.change(17, vs: 100, weekIsOver: true) == "-83 % vs sem. préc.")
        #expect(WeekReview.change(110, vs: 100, weekIsOver: true) == "+10 % vs sem. préc.")
        #expect(WeekReview.change(5, vs: 0, weekIsOver: true) == nil, "no previous data: nothing to compare")
    }
}

/// The « Ce que je remarque » messages never rest on a handful of sessions or a gap that is noise.
@Suite struct InsightSampleTests {
    private let calendar = Calendar.current
    private func points(thursdays: Int, thursdayScore: Double, others: Int = 8, otherScore: Double = 1) -> [Insights.Point] {
        var base = DateComponents(year: 2026, month: 3, day: 2, hour: 12)  // a Monday
        base.calendar = calendar
        let monday = calendar.date(from: base) ?? .now
        func point(_ offset: Int, _ score: Double) -> Insights.Point {
            Insights.Point(date: calendar.date(byAdding: .day, value: offset, to: monday) ?? monday, score: score, daysSincePrevious: nil, previousDayKcal: nil)
        }
        return (0..<others).map { point($0 * 7, otherScore) } + (0..<thursdays).map { point($0 * 7 + 3, thursdayScore) }
    }

    @Test func twoThursdaysAreNotATrend() {
        let found = Insights.insights(from: points(thursdays: 2, thursdayScore: 1.3))
        #expect(!found.contains { $0.id == "weekday" }, "« top le jeudi +22 % » on 2 sessions")
    }

    @Test func aRealPatternOnEnoughSessionsStillShows() {
        let found = Insights.insights(from: points(thursdays: 5, thursdayScore: 1.3))
        #expect(found.contains { $0.id == "weekday" && $0.sampleSize >= Insights.minPerGroup })
    }

    @Test func aGapUnderFivePercentIsNoise() {
        let found = Insights.insights(from: points(thursdays: 6, thursdayScore: 1.04))
        #expect(!found.contains { $0.id == "weekday" }, "« +4 % » is not worth a message")
    }
}
