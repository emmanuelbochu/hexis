import Foundation

/// Checks the phase aimed at against the scale: on track, too slow or too fast, with the daily calories to move
/// (7 700 kcal per kg) and one detail line: low protein, else the maintenance worked out from food and weight.
struct PhaseCheck: Equatable {
    enum Verdict: Equatable { case onTrack, tooSlow, tooFast }

    var verdict: Verdict
    var text: String
    var detail: String?
    /// Calories per day the plan moves by (+ or −) to get back to the middle of the range: steps of 50, at most `stepKcal`.
    var kcalDelta: Int

    static let stepKcal = 150

    /// Weekly weight change aimed at, in kg.
    static func range(for kind: NutritionPhase.Kind) -> ClosedRange<Double> {
        switch kind {
        case .bulk: 0.10...0.20
        case .cut: -0.70 ... -0.25
        case .maintain: -0.10...0.10
        }
    }

    static func make(goal: NutritionPhase.Kind, slope: BodyInsights.Slope?, proteinRange: ClosedRange<Double>) -> PhaseCheck? {
        guard let slope else { return nil }
        let range = range(for: goal)
        let rate = String(format: "%+.2f", slope.kgPerWeek).replacingOccurrences(of: ".", with: ",")
        let target = "\(String(format: "%+.2f", range.lowerBound)) à \(String(format: "%+.2f", range.upperBound))".replacingOccurrences(of: ".", with: ",")
        let mid = (range.lowerBound + range.upperBound) / 2
        let kcal = Int(((mid - slope.kgPerWeek) * 7700 / 7 / 50).rounded()) * 50
        let delta = min(max(kcal, -stepKcal), stepKcal)
        let verdict: Verdict = range.contains(slope.kgPerWeek) ? .onTrack : slope.kgPerWeek < range.lowerBound ? .tooSlow : .tooFast
        let text: String
        switch verdict {
        case .onTrack: text = "Sur la bonne voie : \(rate) kg/sem. (cible \(target))."
        case .tooSlow: text = "\(rate) kg/sem., sous la cible (\(target))."
        case .tooFast: text = "\(rate) kg/sem., au-dessus de la cible (\(target))."
        }
        var detail: String?
        if let protein = slope.proteinPerDay, protein < proteinRange.lowerBound {
            detail = "Protéines \(Int(protein)) g/j : vise au moins \(Int(proteinRange.lowerBound)) g."
        } else if let eaten = slope.kcalPerDay, eaten >= 1500 {
            let maintenance = Int((Double(eaten) - slope.kgPerWeek * 7700 / 7) / 50) * 50
            detail = "Ta maintenance est d'environ \(maintenance) kcal/j (tu manges \(eaten))."
        }
        return PhaseCheck(verdict: verdict, text: text, detail: detail, kcalDelta: verdict == .onTrack ? 0 : delta)
    }
}

extension PhaseCheck {
    /// What is missing to judge the phase: weigh-ins, or days between them.
    static func missing(_ weights: [HealthService.Day], now: Date = .now) -> String {
        let recent = weights.filter { $0.date >= now.addingTimeInterval(-28 * 86_400) }
        guard let first = recent.first, let last = recent.last else {
            return "Aucune pesée dans Santé : pèse-toi 3 fois par semaine pour suivre la prise de masse."
        }
        let kg = String(format: "%.1f", last.value).replacingOccurrences(of: ".", with: ",")
        if recent.count < 4 { return "Dernier poids \(kg) kg · encore \(4 - recent.count) pesée\(recent.count == 3 ? "" : "s") pour juger la prise de masse." }
        let days = max(14 - Int(last.date.timeIntervalSince(first.date) / 86_400), 1)
        return "Dernier poids \(kg) kg · encore \(days) jour\(days > 1 ? "s" : "") de pesées pour juger la prise de masse."
    }
}
