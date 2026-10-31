import Foundation

/// Crosses sessions, sets, time and food to find what the user performs best with. Everything is a trend, with its sample size.
enum Insights {
    struct Insight: Identifiable, Equatable {
        var id: String
        var symbol: String
        var text: String
        var sampleSize: Int
        var unit = "séances"
    }

    /// One finished session scored against the volume of the previous sessions of its template (1.0 = as usual).
    struct Point {
        var date: Date
        var score: Double
        var daysSincePrevious: Int?
        var previousDayKcal: Int?
    }

    static func points(sessions: [WorkoutSession], sets: [SetLog], loads: LoadResolver, intake: [Date: Macros]) -> [Point] {
        let finished = sessions.filter { $0.state == .finished }.sorted { $0.startedAt < $1.startedAt }
        let setsBySession = Dictionary(grouping: sets, by: \.sessionID)
        let volumes = finished.map { loads.volume(setsBySession[$0.id] ?? []) }
        let byTemplate = Dictionary(grouping: finished.indices, by: { finished[$0].templateID })
        let calendar = Calendar.current
        var result: [Point] = []
        // Scored against the 4 previous sessions of the same template, so a rise with time (more weight, more food) is not
        // mistaken for the effect of the day, the food or the sleep.
        let position = Dictionary(uniqueKeysWithValues: byTemplate.values.flatMap { group in group.enumerated().map { ($1, ($0, group)) } })
        for (i, session) in finished.enumerated() {
            guard volumes[i] > 0, let (k, group) = position[i] else { continue }
            let prior = group[max(0, k - 4)..<k].map { volumes[$0] }.filter { $0 > 0 }
            guard prior.count >= 2 else { continue }
            let mean = prior.reduce(0, +) / Double(prior.count)
            let previous = i > 0 ? calendar.dateComponents([.day], from: calendar.startOfDay(for: finished[i - 1].startedAt), to: calendar.startOfDay(for: session.startedAt)).day : nil
            let eve = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: session.startedAt)) ?? session.startedAt
            result.append(Point(
                date: session.startedAt, score: volumes[i] / mean, daysSincePrevious: previous,
                previousDayKcal: intake[eve]?.kcal
            ))
        }
        return result
    }

    static func insights(from points: [Point]) -> [Insight] {
        var found: [Insight] = []
        let average = points.isEmpty ? 1 : points.map(\.score).reduce(0, +) / Double(points.count)

        let weekday = Dictionary(grouping: points, by: { Calendar.current.component(.weekday, from: $0.date) })
        if let best = best(weekday, average: average), let name = WeekdayName.short(best.key) {
            found.append(.init(id: "weekday", symbol: "calendar", text: "Tu es au top le \(name) : \(percent(best.delta)) de volume vs ta moyenne.", sampleSize: best.count))
        }
        let slot = Dictionary(grouping: points, by: { daySlot(Calendar.current.component(.hour, from: $0.date)) })
        if let best = best(slot, average: average) {
            found.append(.init(id: "slot", symbol: "clock", text: "Séances \(best.key) : \(percent(best.delta)) de volume vs ta moyenne.", sampleSize: best.count))
        }
        let rest = Dictionary(grouping: points.filter { $0.daysSincePrevious != nil }, by: { restBucket($0.daysSincePrevious ?? 0) })
        if let best = best(rest, average: average) {
            found.append(.init(id: "rest", symbol: "bed.double", text: "Avec \(best.key) de repos avant : \(percent(best.delta)) de volume.", sampleSize: best.count))
        }
        if let food = foodInsight(points) { found.append(food) }
        return found
    }

    /// Splits sessions at the median kcal eaten the day before.
    private static func foodInsight(_ points: [Point]) -> Insight? {
        let fed = points.compactMap { point in point.previousDayKcal.map { (kcal: $0, score: point.score) } }
        guard fed.count >= 6 else { return nil }
        let median = fed.map(\.kcal).sorted()[fed.count / 2]
        let high = fed.filter { $0.kcal >= median }.map(\.score)
        let low = fed.filter { $0.kcal < median }.map(\.score)
        guard high.count >= 3, low.count >= 3 else { return nil }
        let delta = high.reduce(0, +) / Double(high.count) - low.reduce(0, +) / Double(low.count)
        guard abs(delta) >= 0.04 else { return nil }
        let text = delta > 0
            ? "Après une veille à plus de \(median) kcal, tes séances sont \(percent(delta)) plus volumineuses."
            : "Après une veille à plus de \(median) kcal, tes séances sont \(percent(-delta)) moins volumineuses."
        return .init(id: "food", symbol: "fork.knife", text: text, sampleSize: fed.count)
    }

    private struct Best<Key> {
        var key: Key
        var delta: Double
        var count: Int
    }

    static let minPerGroup = 4
    static let minGap = 0.05

    /// The group (≥ `minPerGroup` sessions) furthest above the average, when there are at least two groups and the gap is `minGap` or more:
    /// two Thursdays or a 4 % gap are chance, not a trend.
    private static func best<Key: Hashable>(_ groups: [Key: [Point]], average: Double) -> Best<Key>? {
        let usable = groups.filter { $0.value.count >= minPerGroup }
        guard usable.count >= 2 else { return nil }
        let ranked = usable.map { Best(key: $0.key, delta: $0.value.map(\.score).reduce(0, +) / Double($0.value.count) - average, count: $0.value.count) }
        guard let top = ranked.max(by: { $0.delta < $1.delta }), top.delta >= minGap else { return nil }
        return top
    }

    private static func percent(_ delta: Double) -> String {
        "\(delta >= 0 ? "+" : "−")\(Int((abs(delta) * 100).rounded())) %"
    }

    private static func daySlot(_ hour: Int) -> String {
        switch hour {
        case ..<12: "du matin"
        case 12..<17: "d'après-midi"
        default: "du soir"
        }
    }

    private static func restBucket(_ days: Int) -> String {
        switch days {
        case ...1: "0–1 jour"
        case 2: "2 jours"
        default: "3 jours ou plus"
        }
    }

    /// Most actionable first, one line per theme: body and food trends, then exercise order, then when and where to train.
    static func ranked(_ insights: [Insight]) -> [Insight] {
        func priority(_ id: String) -> Int {
            switch id {
            case "weight": 0
            case "steps": 1
            case "food": 2
            case _ where id.hasPrefix("position"): 3
            case "speed-all": 4
            case "weekday": 5
            case "slot": 6
            case "rest": 7
            default: 99
            }
        }
        return insights.filter { priority($0.id) < 99 }.sorted { priority($0.id) < priority($1.id) }
    }
}
