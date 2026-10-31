import Foundation

/// The partner eats at home on weekends and picks from the staples: a small margin on those foods for Saturday and Sunday
/// meals only (never the steaks, which she does not eat), kept low so the budget does not grow.
enum GuestMargin {
    static let factor = 0.2
    private static let staples = ["poulet", "pates", "riz", "sauce"]

    static func isStaple(_ food: Ingredient) -> Bool {
        let name = food.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "fr_FR"))
        return staples.contains { name.contains($0) }
    }

    /// Extra grams per food for the weekend meals of the plan.
    static func extra(meals: [PlanMeal], ingredients: [Ingredient]) -> [UUID: Double] {
        let weekend = PlanCalculator.weeklyNeeds(meals.filter { [7, 1].contains($0.weekday) })
        var result: [UUID: Double] = [:]
        for food in ingredients where isStaple(food) {
            if let grams = weekend[food.id] { result[food.id] = grams * factor }
        }
        return result
    }
}
