import Foundation

/// Totals the macros and grams the meal plan needs over a cycle.
enum PlanCalculator {
    static func lookup(_ ingredients: [Ingredient]) -> [UUID: Ingredient] {
        Dictionary(ingredients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func macros(of items: [PlanItem], ingredients: [UUID: Ingredient]) -> Macros {
        var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        for item in items {
            guard let food = ingredients[item.ingredientID] else { continue }
            let ratio = item.grams / 100
            kcal += food.kcal * ratio
            protein += food.protein * ratio
            carbs += food.carbs * ratio
            fat += food.fat * ratio
        }
        return Macros(kcal: Int(kcal.rounded()), protein: protein, carbs: carbs, fat: fat)
    }

    static func macros(of meals: [PlanMeal], ingredients: [UUID: Ingredient]) -> Macros {
        macros(of: meals.flatMap(\.items), ingredients: ingredients)
    }

    /// Total grams needed per ingredient over the whole weekly plan.
    static func weeklyNeeds(_ meals: [PlanMeal]) -> [UUID: Double] {
        var needs: [UUID: Double] = [:]
        for item in meals.flatMap(\.items) { needs[item.ingredientID, default: 0] += item.grams }
        return needs
    }
}
