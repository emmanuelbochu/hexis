import Foundation

/// A cycle runs Monday to Sunday, but flips on Friday at 18:00: the list is ready that evening for Saturday morning's shopping,
/// and the batch cooking follows on Sunday for the week to come.
enum PlanCycle {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static let flipHour = 18

    /// Monday of the week the user is preparing (next Monday from Friday 18:00 on).
    static func start(for date: Date = .now) -> Date {
        let next = calendar.date(byAdding: .hour, value: 72 - flipHour, to: date) ?? date
        return calendar.dateInterval(of: .weekOfYear, for: next)?.start ?? calendar.startOfDay(for: next)
    }

    /// Meals of the cycle whose day is already over: whether eaten or not they no longer need shopping (free days stay out of the list).
    static func pastMealIDs(_ meals: [PlanMeal], cycle: Date, now: Date = .now) -> Set<UUID> {
        let today = calendar.startOfDay(for: now)
        return Set(meals.filter { meal in
            guard let day = calendar.date(byAdding: .day, value: (meal.weekday + 5) % 7, to: cycle) else { return false }
            return day < today
        }.map(\.id))
    }

    /// Meals of the week still running that are left to eat (from Friday evening, once the cycle has flipped to next week):
    /// their food is still in the stock but is not available for next week's list.
    static func remainingMeals(_ meals: [PlanMeal], eatenToday: Set<UUID>, now: Date = .now) -> [PlanMeal] {
        guard let thisMonday = calendar.dateInterval(of: .weekOfYear, for: now)?.start, start(for: now) > thisMonday else { return [] }
        let today = (calendar.component(.weekday, from: now) + 5) % 7
        return meals.filter { meal in
            let day = (meal.weekday + 5) % 7
            return day > today || (day == today && !eatenToday.contains(meal.id))
        }
    }

    /// The next Friday at the flip hour: the list is ready.
    static func nextListReady(after date: Date) -> Date? {
        calendar.nextDate(after: date, matching: DateComponents(hour: flipHour, weekday: 6), matchingPolicy: .nextTime)
    }

    /// Friday at the flip hour before the cycle: batch steps done since then count for this cycle (a step ticked on
    /// Friday evening or Saturday, to read ahead or cook early, is not lost).
    static func batchWindowStart(for date: Date = .now) -> Date {
        calendar.date(byAdding: .hour, value: flipHour - 72, to: start(for: date)) ?? start(for: date)
    }
}
