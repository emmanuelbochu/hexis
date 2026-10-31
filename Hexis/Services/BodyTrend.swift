import Foundation

/// Weight and step trends from Health samples; pure, so it is easy to reason about and to word for the coach.
struct BodyTrend: Equatable {
    /// Mean weight of the 7 days up to `end` and of the 7 days before, in kg.
    let weight: Double?
    let previousWeight: Double?
    let weighIns: Int
    /// Mean steps per day over the 7 days up to `end`, and over the 7 days before.
    let steps: Int?
    let previousSteps: Int?

    var weightChange: Double? {
        guard let weight, let previousWeight else { return nil }
        return weight - previousWeight
    }

    init(weights: [HealthService.Day], steps dailySteps: [HealthService.Day], end: Date, calendar: Calendar = .current) {
        let endDay = calendar.startOfDay(for: end)
        func window(_ days: [HealthService.Day], back: Int) -> [HealthService.Day] {
            guard let upper = calendar.date(byAdding: .day, value: 1 - back, to: endDay),
                  let lower = calendar.date(byAdding: .day, value: -7, to: upper)
            else { return [] }
            return days.filter { $0.date >= lower && $0.date < upper }
        }
        func mean(_ days: [HealthService.Day]) -> Double? {
            days.isEmpty ? nil : days.reduce(0) { $0 + $1.value } / Double(days.count)
        }
        let now = window(weights, back: 0), before = window(weights, back: 7)
        weight = mean(now)
        previousWeight = mean(before)
        weighIns = now.count
        steps = mean(window(dailySteps, back: 0)).map { Int($0.rounded()) }
        previousSteps = mean(window(dailySteps, back: 7)).map { Int($0.rounded()) }
    }
}
