import Foundation
import Testing
@testable import HexisLogic

/// Hexis Elle's rhythm: weeks held in a row, one joker in four, the running week never breaks anything.
@Suite struct HabitStreakTests {
    private let calendar = WeekReview.calendar
    /// Wednesday 28 October 2026, noon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)) ?? .now }

    /// Two sessions in each listed week (0 = this one, 1 = last week…), the first of them on Monday.
    private func weeks(_ offsets: [Int], perWeek: Int = 2) -> [Date] {
        offsets.flatMap { offset -> [Date] in
            let start = WeekReview.weekStart(containing: now, offset: -offset)
            return (0..<perWeek).compactMap { calendar.date(byAdding: .day, value: $0 * 2, to: start)?.addingTimeInterval(36_000) }
        }
    }

    private func streak(_ dates: [Date]) -> HabitStreak { HabitStreak(sessionDates: dates, weeklyTarget: 2, now: now, calendar: calendar) }

    @Test func weeksInARowCountAndTheRunningWeekOnlyWhenItIsDone() {
        #expect(streak(weeks([1, 2, 3])).streak == 3)
        #expect(streak(weeks([0, 1, 2])).streak == 3)
    }

    @Test func oneMissedWeekIsForgivenByTheJokerAndDoesNotAddUp() {
        // Done 5, 4, 3, then 2 missed, then 1 done: the miss is a joker, the chain goes on.
        let result = streak(weeks([1, 3, 4, 5]))
        #expect(result.streak == 4)
        #expect(result.weeks[result.weeks.count - 3] == .joker)
    }

    @Test func twoMissedWeeksInAFourWeekWindowBreakTheStreak() {
        // Weeks 2 and 1 both missed after a long run: the second miss is not forgiven.
        #expect(streak(weeks([3, 4, 5, 6])).streak == 0)
    }

    @Test func aJokerComesBackAfterThreeWeeks() {
        let result = streak(weeks([1, 2, 3, 5, 6, 7]))
        // Week 4 missed (joker), then 3 weeks held: another miss would be forgiven again.
        #expect(result.jokerAvailable)
        #expect(streak(weeks([1, 3, 4, 5])).jokerAvailable == false)
    }

    @Test func theFirstWeekStartedMidwayIsNotAMissNorAJoker() {
        let start = WeekReview.weekStart(containing: now, offset: -3)
        let first = start.addingTimeInterval(4 * 86_400 + 36_000)
        let result = streak([first] + weeks([2, 1]))
        #expect(result.streak == 2 && result.jokerAvailable)
    }

    @Test func noSessionYetMeansNothingToLose() {
        let result = streak([])
        #expect(result.streak == 0 && result.jokerAvailable)
        #expect(result.weeks.last == .running(0))
    }

    @Test func monthAgainstTheMonthBefore() {
        let result = HabitStreak(sessionDates: weeks([0, 1, 5]), weeklyTarget: 2, now: now, calendar: calendar)
        #expect(result.thisMonth + result.lastMonth == 6)
    }
}
