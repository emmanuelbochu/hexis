import Foundation

/// Crosses body weight, steps and food with training. Every line is a trend with its sample size; the AI only rewords them.
enum BodyInsights {
    struct Slope: Equatable {
        var kgPerWeek: Double
        var weighIns: Int
        var kcalPerDay: Int?
        var proteinPerDay: Double?
    }

    /// Weight slope over the last 28 days (least squares), needs 4 weigh-ins spread over 14 days or more.
    static func slope(weights: [HealthService.Day], intake: [Date: Macros], now: Date = .now, calendar: Calendar = .current) -> Slope? {
        guard let start = calendar.date(byAdding: .day, value: -28, to: now) else { return nil }
        let recent = weights.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        guard recent.count >= 4, let first = recent.first, let last = recent.last,
              last.date.timeIntervalSince(first.date) >= 14 * 86_400
        else { return nil }
        let xs = recent.map { $0.date.timeIntervalSince(first.date) / 86_400 }
        let ys = recent.map(\.value)
        let meanX = xs.reduce(0, +) / Double(xs.count), meanY = ys.reduce(0, +) / Double(ys.count)
        let variance = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard variance > 0 else { return nil }
        let covariance = zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let kcal = DailyIntake.mean(intake, from: first.date, now: now, calendar: calendar) { Double($0.kcal) }
        let protein = DailyIntake.mean(intake, from: first.date, now: now, calendar: calendar) { $0.protein }
        return Slope(kgPerWeek: covariance / variance * 7, weighIns: recent.count, kcalPerDay: kcal.map { Int($0.rounded()) }, proteinPerDay: protein)
    }

    static func insights(points: [Insights.Point], steps: [HealthService.Day], weights: [HealthService.Day], intake: [Date: Macros], now: Date = .now) -> [Insights.Insight] {
        [stepsInsight(points: points, steps: steps), weightInsight(slope(weights: weights, intake: intake, now: now), points: points)].compactMap { $0 }
    }

    /// Splits sessions at the median steps walked the day before.
    private static func stepsInsight(points: [Insights.Point], steps: [HealthService.Day], calendar: Calendar = .current) -> Insights.Insight? {
        let byDay = Dictionary(steps.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { first, _ in first })
        let walked = points.compactMap { point -> (steps: Int, score: Double)? in
            guard let eve = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: point.date)),
                  let count = byDay[eve] else { return nil }
            return (Int(count), point.score)
        }
        guard walked.count >= 6 else { return nil }
        let median = walked.map(\.steps).sorted()[walked.count / 2]
        let high = walked.filter { $0.steps >= median }.map(\.score), low = walked.filter { $0.steps < median }.map(\.score)
        guard high.count >= 3, low.count >= 3 else { return nil }
        let delta = high.reduce(0, +) / Double(high.count) - low.reduce(0, +) / Double(low.count)
        guard abs(delta) >= 0.04 else { return nil }
        let percent = "\(Int((abs(delta) * 100).rounded())) %"
        let text = delta > 0
            ? "Après une veille à plus de \(median.formatted()) pas, tes séances sont \(percent) plus volumineuses."
            : "Après une veille à plus de \(median.formatted()) pas, tes séances sont \(percent) moins volumineuses."
        return .init(id: "steps", symbol: "figure.walk", text: text, sampleSize: walked.count)
    }

    /// Weight trend with the food eaten over the same weeks; flags a fast loss since it eats into recovery.
    private static func weightInsight(_ slope: Slope?, points: [Insights.Point]) -> Insights.Insight? {
        guard let slope, abs(slope.kgPerWeek) >= 0.1 else { return nil }
        let rate = String(format: "%+.1f", slope.kgPerWeek).replacingOccurrences(of: ".", with: ",")
        var text = "Poids \(rate) kg par semaine"
        if let kcal = slope.kcalPerDay { text += " avec \(kcal.formatted()) kcal/j en moyenne" }
        text += "."
        if slope.kgPerWeek <= -0.7 { text += " Perte rapide : surveille ta récupération." }
        return .init(id: "weight", symbol: "scalemass", text: text, sampleSize: slope.weighIns, unit: "pesées")
    }
}
