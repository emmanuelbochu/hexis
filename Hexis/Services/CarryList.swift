import Foundation

/// What to bring to the flat on Sunday evening: the plan's foods from Sunday's « Après dîner » to Friday's « Collation »
/// (home again on Friday evening), minus what the batch cooks (it leaves in the boxes) and what stays at the flat.
enum CarryList {
    struct Line: Identifiable {
        let food: Ingredient
        let grams: Double
        /// Plan items of the food in the window: the bread is frozen in one piece per meal.
        let portions: Int

        var id: UUID { food.id }

        var text: String {
            food.category == ShoppingList.bakery ? "\(portions) bouts" : QuantityFormatter.text(grams: grams, of: food)
        }
    }

    /// Sunday evening the bag is packed: the list leaves the screen from this hour.
    static let hiddenFromHour = 21

    /// Meals eaten at the flat: Sunday after dinner to Friday's snack.
    static func isAtFlat(_ meal: PlanMeal) -> Bool {
        switch meal.weekday {
        case 1: meal.slot.order > MealSlot.dinner.order
        case 2...5: true
        case 6: meal.slot.order <= MealSlot.snack.order
        default: false
        }
    }

    /// A food is cooked in the batch when its first word names a step ("Steak haché" ↔ "Steaks", "Riz" ↔ "Riz").
    static func isBatchCooked(_ food: Ingredient, steps: [BatchStep]) -> Bool {
        guard let word = words(food.name).first else { return false }
        return steps.contains { words($0.title).contains(word) }
    }

    /// `flat` is what the flat already holds of the staples (`FlatStockBook`): they are carried only for what it lacks.
    static func lines(meals: [PlanMeal], ingredients: [Ingredient], steps: [BatchStep], flat: [UUID: Double] = [:]) -> [Line] {
        var grams: [UUID: Double] = [:]
        var portions: [UUID: Int] = [:]
        for item in meals.filter(isAtFlat).flatMap(\.items) {
            grams[item.ingredientID, default: 0] += item.grams
            portions[item.ingredientID, default: 0] += 1
        }
        let order = ShoppingList.categoryOrder
        return ingredients.compactMap { food in
            guard let need = grams[food.id], need > 0, !isBatchCooked(food, steps: steps) else { return nil }
            let total = FlatStockBook.isStaple(food) ? FlatStockBook.deficit(need: need, atFlat: flat[food.id] ?? 0, food: food) : need
            return total > 0 ? Line(food: food, grams: total, portions: portions[food.id] ?? 0) : nil
        }
        .sorted { lhs, rhs in
            let l = order.firstIndex(of: lhs.food.category) ?? order.count
            let r = order.firstIndex(of: rhs.food.category) ?? order.count
            return l == r ? lhs.food.name < rhs.food.name : l < r
        }
    }

    /// Lowercased words without accents nor plural s.
    private static func words(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
            .split { !$0.isLetter }
            .map { $0.hasSuffix("s") ? String($0.dropLast()) : String($0) }
    }
}
