import Foundation

/// Hexis Elle's rhythm: weeks that reached the target, in a row, with a joker: one missed week in four does not break the streak.
/// A week before the first session never counts as missed; the running week never breaks anything until it is over.
struct HabitStreak: Equatable {
    enum Week: Equatable {
        case done, joker, missed, running(Int), before
    }

    var weeklyTarget: Int
    /// The last 8 weeks, oldest first, the running one last.
    var weeks: [Week]
    /// Weeks that reached the target in the unbroken chain (jokers keep it going without adding to it).
    var streak: Int
    /// Sessions in the calendar month of `now`, and in the month before.
    var thisMonth: Int
    var lastMonth: Int
    /// A joker is still available if none was used in the last 3 weeks.
    var jokerAvailable: Bool

    static let shownWeeks = 8

    init(sessionDates: [Date], weeklyTarget: Int, now: Date = .now, calendar: Calendar = .current) {
        let target = max(weeklyTarget, 1)
        self.weeklyTarget = target
        let counts = Dictionary(grouping: sessionDates, by: { WeekReview.weekStart(containing: $0) }).mapValues(\.count)
        let current = WeekReview.weekStart(containing: now)
        let first = sessionDates.min().map { WeekReview.weekStart(containing: $0) }
        func week(_ offset: Int) -> Date { WeekReview.weekStart(containing: current, offset: offset) }
        func isBefore(_ offset: Int) -> Bool { first.map { week(offset) < $0 } ?? true }

        // Oldest to newest over the whole history, jokers decided as the weeks go by.
        let back = first.map { max(0, WeekReview.calendar.dateComponents([.weekOfYear], from: $0, to: current).weekOfYear ?? 0) } ?? 0
        var states: [Int: Week] = [:]
        var chain = 0
        var lastJoker: Int?
        for offset in stride(from: -back, through: -1, by: 1) {
            if offset == -back, (counts[week(offset)] ?? 0) < target {
                // The first week is usually started midway: neither a miss nor a joker.
                states[offset] = .before
            } else if (counts[week(offset)] ?? 0) >= target {
                states[offset] = .done
                chain += 1
            } else if let used = lastJoker, offset - used < 4 {
                states[offset] = .missed
                chain = 0
                lastJoker = nil
            } else {
                states[offset] = .joker
                lastJoker = offset
            }
        }
        let running = counts[current] ?? 0
        if running >= target { chain += 1 }
        streak = chain
        weeks = (-(Self.shownWeeks - 1)...0).map { offset in
            if offset == 0 { return .running(running) }
            return isBefore(offset) ? .before : (states[offset] ?? .before)
        }
        jokerAvailable = lastJoker.map { -1 - $0 >= 3 } ?? true

        let month = calendar.dateComponents([.year, .month], from: now)
        let previous = calendar.date(byAdding: .month, value: -1, to: now).map { calendar.dateComponents([.year, .month], from: $0) }
        thisMonth = sessionDates.filter { calendar.dateComponents([.year, .month], from: $0) == month }.count
        lastMonth = sessionDates.filter { calendar.dateComponents([.year, .month], from: $0) == previous }.count
    }
}
