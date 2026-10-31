import Foundation
import SwiftData

/// Validating a planned meal logs its macros in one tap; removing the entry undoes it (stock included).
enum MealLogger {
    /// Logs the meal and lowers the stock; nil when it was already validated today (a double tap must not count twice).
    @discardableResult
    static func eat(_ meal: PlanMeal, ingredients: [UUID: Ingredient], in context: ModelContext, now: Date = .now) -> FoodEntry? {
        let today = Calendar.current.startOfDay(for: now)
        let mealID = meal.id
        let existing = (try? context.fetchCount(FetchDescriptor<PlanMealLog>(predicate: #Predicate { $0.planMealID == mealID && $0.day >= today }))) ?? 0
        guard existing == 0 else { return nil }
        let macros = PlanCalculator.macros(of: meal.items, ingredients: ingredients)
        let entry = FoodEntry(
            date: now, meal: meal.slot, name: "Plan · \(meal.slot.label)",
            kcal: macros.kcal, protein: macros.protein, carbs: macros.carbs, fat: macros.fat
        )
        context.insert(entry)
        for item in meal.items { ingredients[item.ingredientID]?.stockGrams = max(0, (ingredients[item.ingredientID]?.stockGrams ?? 0) - item.grams) }
        FlatStockBook.shift(meal, sign: -1, foods: ingredients, in: context)
        context.insert(PlanMealLog(planMealID: meal.id, day: today, entryID: entry.id))
        context.saveReportingFailure()
        return entry
    }

    /// Takes a validated meal back: the entry goes, the log goes, the food is back in the stock.
    static func undo(entryID: UUID, ingredients: [UUID: Ingredient], in context: ModelContext) {
        let logs = (try? context.fetch(FetchDescriptor<PlanMealLog>(predicate: #Predicate { $0.entryID == entryID }))) ?? []
        for log in logs {
            let mealID = log.planMealID
            let meal = (try? context.fetch(FetchDescriptor<PlanMeal>(predicate: #Predicate { $0.id == mealID })))?.first
            for item in meal?.items ?? [] { ingredients[item.ingredientID]?.stockGrams += item.grams }
            if let meal { FlatStockBook.shift(meal, sign: 1, foods: ingredients, in: context) }
            context.delete(log)
        }
        for entry in (try? context.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.id == entryID }))) ?? [] { context.delete(entry) }
        context.saveReportingFailure()
    }
}
