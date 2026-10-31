import Foundation
import SwiftData

/// What was really eaten on a day: the foods logged, plus the plan meals of the slots already gone with nothing logged in
/// them (assumed eaten, as `StockReconciler` does for the stock). A day with only breakfast logged is not a 600 kcal day.
enum DailyIntake {
    /// Macros of one day. Today counts only the slots before the current one; a future day counts nothing planned.
    static func macros(
        on day: Date, entries: [FoodEntry], meals: [PlanMeal], ingredients: [UUID: Ingredient],
        now: Date = .now, calendar: Calendar = .current
    ) -> Macros {
        var total = NutritionTotals.sum(NutritionTotals.entries(entries, on: day, calendar: calendar))
        let dayStart = calendar.startOfDay(for: day), today = calendar.startOfDay(for: now)
        let due: Set<MealSlot>
        if dayStart < today {
            due = Set(MealSlot.allCases)
        } else if dayStart == today {
            let current = MealSlot.current(hour: calendar.component(.hour, from: now)).order
            due = Set(MealSlot.allCases.filter { $0.order < current })
        } else {
            return total
        }
        let logged = Set(NutritionTotals.entries(entries, on: day, calendar: calendar).map(\.mealRaw))
        let weekday = calendar.component(.weekday, from: day)
        let assumed = PlanCalculator.macros(
            of: meals.filter { $0.weekday == weekday && due.contains($0.slot) && !logged.contains($0.slotRaw) }, ingredients: ingredients
        )
        total.kcal += assumed.kcal
        total.protein += assumed.protein
        total.carbs += assumed.carbs
        total.fat += assumed.fat
        return total
    }

    /// Macros of each past day (today excluded) that was really tracked (3 meal slots logged at least); a day eaten out or on
    /// holiday, with one tap or none, says nothing about the intake.
    static func byDay(
        entries: [FoodEntry], meals: [PlanMeal], ingredients: [UUID: Ingredient], since: Date,
        now: Date = .now, calendar: Calendar = .current
    ) -> [Date: Macros] {
        let today = calendar.startOfDay(for: now)
        let grouped = Dictionary(grouping: entries.filter { $0.date >= since }, by: { calendar.startOfDay(for: $0.date) })
        var result: [Date: Macros] = [:]
        for (day, dayEntries) in grouped where day < today && Set(dayEntries.map(\.mealRaw)).count >= 3 {
            result[day] = macros(on: day, entries: dayEntries, meals: meals, ingredients: ingredients, now: now, calendar: calendar)
        }
        return result
    }

    /// Same, read from the store (only the entries since `since`).
    static func load(in context: ModelContext, since: Date, now: Date = .now) -> [Date: Macros] {
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.date >= since }))) ?? []
        let meals = (try? context.fetch(FetchDescriptor<PlanMeal>())) ?? []
        let ingredients = PlanCalculator.lookup((try? context.fetch(FetchDescriptor<Ingredient>())) ?? [])
        return byDay(entries: entries, meals: meals, ingredients: ingredients, since: since, now: now)
    }

    /// Mean of a macro over the days in `[from, now)` that have data; nil under 5 such days.
    static func mean(_ intake: [Date: Macros], from: Date, now: Date = .now, calendar: Calendar = .current, _ value: (Macros) -> Double) -> Double? {
        let start = calendar.startOfDay(for: from), today = calendar.startOfDay(for: now)
        let days = intake.filter { $0.key >= start && $0.key < today }
        return days.count >= 5 ? days.values.reduce(0) { $0 + value($1) } / Double(days.count) : nil
    }
}
