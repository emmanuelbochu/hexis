import Foundation
import SwiftData

/// One food logged in a day, with its macros.
@Model
final class FoodEntry {
    var id: UUID
    var date: Date
    var mealRaw: String
    var name: String
    var kcal: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    var meal: MealSlot { MealSlot(rawValue: mealRaw) ?? .snack }

    init(
        id: UUID = UUID(), date: Date = .now, meal: MealSlot, name: String,
        kcal: Int, protein: Double, carbs: Double, fat: Double
    ) {
        self.id = id
        self.date = date
        self.mealRaw = meal.rawValue
        self.name = name
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}
