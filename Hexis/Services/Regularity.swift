import Foundation

/// Weekly regularity: sessions done against the weekly target, and the streak of weeks that hit it.
struct Regularity: Equatable {
    var weeklyTarget: Int
    var thisWeek: Int
    /// Consecutive weeks that reached the target (the running week counts once it does).
    var streak: Int
    var longest: Int
    /// Sessions of the last 8 weeks, oldest first, the running week last.
    var recentWeeks: [Int]

    init(sessionDates: [Date], weeklyTarget: Int, now: Date = .now) {
        let target = max(weeklyTarget, 1)
        self.weeklyTarget = target
        let counts = Dictionary(grouping: sessionDates, by: { WeekReview.weekStart(containing: $0) }).mapValues(\.count)
        let current = WeekReview.weekStart(containing: now)
        func count(_ offset: Int) -> Int { counts[WeekReview.weekStart(containing: current, offset: offset)] ?? 0 }
        thisWeek = count(0)
        recentWeeks = (-7...0).map(count)

        // The running week does not break a streak until it is over.
        var run = 0
        var offset = thisWeek >= target ? 0 : -1
        while count(offset) >= target { run += 1; offset -= 1 }
        streak = run

        let weeksBack = counts.keys.min().map { max(0, WeekReview.calendar.dateComponents([.weekOfYear], from: $0, to: current).weekOfYear ?? 0) } ?? 0
        var best = 0, running = 0
        for back in stride(from: weeksBack, through: 0, by: -1) {
            running = count(-back) >= target ? running + 1 : 0
            best = max(best, running)
        }
        longest = best
    }
}
