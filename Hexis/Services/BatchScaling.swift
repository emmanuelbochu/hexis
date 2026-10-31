import Foundation

/// The batch recipe is written for the starchy quantities of the plan as first seeded; when `PlanAutoAdjust` scales the
/// plan's rice, pasta and oats, the rice and pasta quantities of the steps (and the rice water) follow by the same factor.
enum BatchScaling {
    static func detail(of step: BatchStep, scale: Double) -> String {
        guard abs(scale - 1) > 0.005, ["Riz", "Pâtes"].contains(step.title) else { return step.detail }
        let units = step.title == "Riz" ? "riz|pâtes|eau|d'eau" : "pâtes"
        guard let regex = try? NSRegularExpression(pattern: "(\\d+) g (de (?:\(units))|d'eau)") else { return step.detail }
        var text = step.detail
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let number = Range(match.range(at: 1), in: text), let grams = Double(text[number]) else { continue }
            text.replaceSubrange(number, with: String(Int((grams * scale / 5).rounded()) * 5))
        }
        return text
    }
}
