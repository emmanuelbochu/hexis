import Foundation
import SwiftData

/// The foods kept at the flat (oil, oats, tuna): carried the first time, then only what is missing for the coming week, so they
/// are not brought every Sunday. Eating at the flat uses the flat's part first; Sunday evening the list's quantities are
/// taken to have gone in the bag (no tick needed, the list is only read).
enum FlatStockBook {
    static let staples: Set<String> = ["Huile d'olive", "Flocons d'avoine", "Thon naturel"]
    private static let carriedKey = "flatCarriedOn"

    static func isStaple(_ food: Ingredient) -> Bool { staples.contains(food.name) }

    /// Grams at the flat per food, never more than the food's stock.
    static func grams(_ rows: [FlatStock], foods: [Ingredient]) -> [UUID: Double] {
        let stock = Dictionary(foods.map { ($0.id, $0.stockGrams) }, uniquingKeysWith: { first, _ in first })
        return Dictionary(rows.map { ($0.ingredientID, min($0.grams, max(0, stock[$0.ingredientID] ?? 0))) }, uniquingKeysWith: { first, _ in first })
    }

    /// What the flat still lacks of a staple for the week: the need minus its part, whole boxes for what is counted in pieces.
    static func deficit(need: Double, atFlat: Double, food: Ingredient) -> Double {
        let missing = max(0, need - atFlat)
        guard missing > 0 else { return 0 }
        let step = food.pieceGrams > 0 ? food.pieceGrams : 10
        return (missing / step).rounded(.up) * step
    }

    /// A meal eaten (`sign` = -1) or taken back (+1): the flat's part of the staples follows, for meals eaten at the flat only.
    static func shift(_ meal: PlanMeal, sign: Double, foods: [UUID: Ingredient], in context: ModelContext) {
        guard CarryList.isAtFlat(meal) else { return }
        let rows = (try? context.fetch(FetchDescriptor<FlatStock>())) ?? []
        for item in meal.items {
            guard let food = foods[item.ingredientID], isStaple(food), let row = rows.first(where: { $0.ingredientID == food.id }) else { continue }
            row.grams = min(max(0, row.grams + sign * item.grams), max(0, food.stockGrams + (sign < 0 ? item.grams : 0)))
            row.updatedAt = .now
        }
    }

    /// The most recent Sunday 21:00 at or before `now`.
    static func lastCarryMoment(now: Date, calendar: Calendar = PlanCycle.calendar) -> Date? {
        let day = calendar.startOfDay(for: now)
        let back = (calendar.component(.weekday, from: day) + 6) % 7
        guard let sunday = calendar.date(byAdding: .day, value: -back, to: day),
              let moment = calendar.date(bySettingHour: CarryList.hiddenFromHour, minute: 0, second: 0, of: sunday) else { return nil }
        return moment <= now ? moment : calendar.date(byAdding: .day, value: -7, to: moment)
    }

    /// Once per week, from Sunday 21:00: what the list asked for the staples is now at the flat.
    static func settleCarry(in context: ModelContext, now: Date = .now, defaults: UserDefaults = .standard) {
        guard Edition.hasNutrition, let moment = lastCarryMoment(now: now) else { return }
        let last = defaults.object(forKey: carriedKey) as? Date
        guard last == nil || last! < moment else { return }
        defaults.set(moment, forKey: carriedKey)
        // The first run only marks the week: nothing is invented about a list that was never shown.
        guard last != nil, !FreePeriod.isHolidayCycle(PlanCycle.start(for: moment)) else { return }
        let meals = (try? context.fetch(FetchDescriptor<PlanMeal>())) ?? []
        let foods = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let steps = (try? context.fetch(FetchDescriptor<BatchStep>())) ?? []
        var rows = (try? context.fetch(FetchDescriptor<FlatStock>())) ?? []
        let lines = CarryList.lines(meals: meals, ingredients: foods, steps: steps, flat: grams(rows, foods: foods))
        for line in lines where isStaple(line.food) {
            if let row = rows.first(where: { $0.ingredientID == line.food.id }) {
                row.grams += line.grams
                row.updatedAt = now
            } else {
                let row = FlatStock(ingredientID: line.food.id, grams: line.grams, updatedAt: now)
                context.insert(row)
                rows.append(row)
            }
        }
        context.saveReportingFailure()
    }
}
