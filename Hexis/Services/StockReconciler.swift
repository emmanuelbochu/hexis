import Foundation
import SwiftData

/// Keeps the stock honest when meals are not validated (holidays, free weekends, a forgotten tap): a plan meal of a past
/// day with nothing logged for its slot is assumed eaten from the stock (a plan meal validated already lowered it, another
/// food logged in that slot means it was replaced), and fresh food cannot pile up beyond about a week and a half of the plan.
/// A free stretch (`FreePeriod`: a school holiday, or 3 days in a row with at most one slot logged) is not followed at all: meals out, shopping off the
/// plan, nothing can be guessed, so the stock is left as it was.
enum StockReconciler {
    private static let key = "stockReconciledOn"
    private static let maxDays = 14
    private static let freshCategories: Set<String> = ["Fruits", "Frais", "Boulangerie"]
    private static let freshCap = 1.5

    static func run(in context: ModelContext, now: Date = .now, defaults: UserDefaults = .standard, holidays: [SchoolHoliday] = SchoolHoliday.current) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        let last = (defaults.object(forKey: key) as? Date).map { calendar.startOfDay(for: $0) }
        // First launch with this rule: start from yesterday, never rewrite the past.
        guard let last, last < yesterday else {
            if last == nil { defaults.set(yesterday, forKey: key) }
            return
        }
        let meals = (try? context.fetch(FetchDescriptor<PlanMeal>())) ?? []
        let foods = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        guard !meals.isEmpty, !foods.isEmpty else { return }
        let byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let start = max(calendar.date(byAdding: .day, value: 1, to: last) ?? yesterday, calendar.date(byAdding: .day, value: -maxDays, to: today) ?? yesterday)
        // Days before `start` only tell whether a free stretch began earlier.
        let lookback = calendar.date(byAdding: .day, value: -FreePeriod.runLength, to: start) ?? start
        let loggedByDay = FreePeriod.loggedSlots(from: lookback, to: today, meals: meals, in: context, calendar: calendar)
        let free = FreePeriod.freeDays(loggedByDay.mapValues(\.count), holidays: holidays, calendar: calendar)
        var day = start
        while day <= yesterday {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            if free.contains(day) { day = next; continue }
            let logged = loggedByDay[day] ?? []
            let weekday = calendar.component(.weekday, from: day)
            for meal in meals where meal.weekday == weekday && !logged.contains(meal.slotRaw) {
                FlatStockBook.shift(meal, sign: -1, foods: byID, in: context)
                for item in meal.items {
                    byID[item.ingredientID]?.stockGrams = max(0, (byID[item.ingredientID]?.stockGrams ?? 0) - item.grams)
                }
            }
            day = next
        }
        let needs = PlanCalculator.weeklyNeeds(meals)
        for food in foods where freshCategories.contains(food.category) {
            if let need = needs[food.id], need > 0 { food.stockGrams = min(food.stockGrams, need * freshCap) }
        }
        defaults.set(yesterday, forKey: key)
        context.saveReportingFailure()
    }
}
