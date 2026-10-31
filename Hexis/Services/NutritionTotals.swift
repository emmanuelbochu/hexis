import Foundation

/// Macro totals (kcal, protein, carbs, fat) and their sums over meals and entries.
struct Macros: Equatable {
    var kcal = 0
    var protein = 0.0
    var carbs = 0.0
    var fat = 0.0
}

enum NutritionTotals {
    static func sum(_ entries: [FoodEntry]) -> Macros {
        entries.reduce(into: Macros()) {
            $0.kcal += $1.kcal
            $0.protein += $1.protein
            $0.carbs += $1.carbs
            $0.fat += $1.fat
        }
    }

    /// Entries logged on the same calendar day as `day`.
    static func entries(_ entries: [FoodEntry], on day: Date, calendar: Calendar = .current) -> [FoodEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Progress toward a goal, clamped to 0...1.
    static func progress(_ value: Double, goal: Double) -> Double {
        goal > 0 ? min(max(value / goal, 0), 1) : 0
    }
}
