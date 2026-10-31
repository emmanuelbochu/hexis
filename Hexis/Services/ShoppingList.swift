import Foundation

/// The shopping list: needs of the cycle's uneaten meals minus the stock, in usual packs, with cost.
struct ShoppingLine: Identifiable {
    var food: Ingredient
    var need: Double
    var toBuy: Double
    var packs: Int
    var cost: Double
    var checked: Bool

    var id: UUID { food.id }

    /// Bread comes from the bakery after the shopping, as whole loaves cut and frozen in portions: it has its own wording and stays out of the store budget.
    var isBakery: Bool { food.category == ShoppingList.bakery }

    /// What to take, as the packs usually bought ("3 × 500 g", "2 boîtes", "1 × 12 œufs"), or the weight when the food has no pack.
    var buyText: String {
        if isBakery { return "\(max(packs, 1)) miche\(packs > 1 ? "s" : "")" }
        guard packs > 0, food.packGrams > 0 else { return QuantityFormatter.text(grams: toBuy, of: food) }
        if food.pieceGrams > 0, abs(food.pieceGrams - food.packGrams) < 1 { return QuantityFormatter.text(grams: Double(packs) * food.packGrams, of: food) }
        let pack = food.pieceGrams > 0 ? QuantityFormatter.text(grams: food.packGrams, of: food) : QuantityFormatter.weight(food.packGrams)
        return "\(packs) × \(pack)"
    }
}

enum ShoppingList {
    static let bakery = "Boulangerie"
    /// Frozen portions of bread a week.
    static let portionsPerWeek = 5

    /// Portions of bread to bring: the week's bread in `portionsPerWeek` pieces, minus what the freezer still holds.
    static func portions(for line: ShoppingLine) -> Int {
        guard line.need > 0 else { return 0 }
        return Int((line.toBuy / (line.need / Double(portionsPerWeek))).rounded(.up))
    }

    /// Stock that makes the line covered: what is at home plus what is still missing (« I already have it »).
    static func coveredStock(_ line: ShoppingLine) -> Double { line.food.stockGrams + line.toBuy }

    /// A ticket validates the shopping: what was ticked in store but is not on the ticket was paid too, so it joins the stock
    /// (and leaves the list) like the scanned lines do. Returns the foods settled.
    @discardableResult
    static func settleChecked(_ lines: [ShoppingLine], scanned: Set<UUID>) -> [UUID] {
        let settled = lines.filter { $0.checked && $0.toBuy > 0 && !scanned.contains($0.food.id) }
        for line in settled { line.food.stockGrams = coveredStock(line) }
        return settled.map(\.food.id)
    }

    static let categoryOrder = ["Fruits", "Frais", "Boulangerie", "Épicerie", "Conserves", "Surgelés"]

    /// Needs of the meals of the cycle not eaten yet (eating already lowers the stock) minus what is at home, with packs and estimated cost.
    /// `reserved` is stock already promised to meals of the week still running (grams per ingredient).
    static func lines(
        meals: [PlanMeal], ingredients: [Ingredient], checked: Set<UUID>, eaten: Set<UUID> = [], reserved: [UUID: Double] = [:],
        bought: Set<UUID> = []
    ) -> [ShoppingLine] {
        let left = meals.filter { !eaten.contains($0.id) }
        var needs = PlanCalculator.weeklyNeeds(left)
        for (id, grams) in GuestMargin.extra(meals: left, ingredients: ingredients) { needs[id, default: 0] += grams }
        return ingredients.compactMap { food in
            guard let need = needs[food.id] else { return nil }
            // A food the ticket of this shopping brought is done: the plan's need is not a reason to propose it again.
            let toBuy = bought.contains(food.id) ? 0 : max(0, need - max(0, food.stockGrams - (reserved[food.id] ?? 0)))
            // A few grams over a whole pack (< 2 % of it) do not buy one more.
            let packs = food.packGrams > 0 && toBuy > 0 ? max(1, Int(((toBuy - 0.02 * food.packGrams) / food.packGrams).rounded(.up))) : 0
            let cost = food.packGrams > 0 ? Double(packs) * food.packPrice : toBuy / 1000 * food.packPrice
            return ShoppingLine(food: food, need: need, toBuy: toBuy, packs: packs, cost: cost, checked: checked.contains(food.id))
        }
        .sorted { lhs, rhs in
            let l = categoryOrder.firstIndex(of: lhs.food.category) ?? categoryOrder.count
            let r = categoryOrder.firstIndex(of: rhs.food.category) ?? categoryOrder.count
            return l == r ? lhs.food.name < rhs.food.name : l < r
        }
    }

    /// The list of the cycle running at `now`: meals eaten or of past days left out, food still promised to this week kept aside.
    static func cycleLines(meals: [PlanMeal], ingredients: [Ingredient], logs: [PlanMealLog], checked: Set<UUID>, purchases: [PurchaseLog] = [], now: Date = .now) -> [ShoppingLine] {
        let cycle = PlanCycle.start(for: now)
        let end = PlanCycle.calendar.date(byAdding: .day, value: 7, to: cycle) ?? cycle
        let eaten = Set(logs.filter { $0.day >= cycle && $0.day < end }.map(\.planMealID)).union(PlanCycle.pastMealIDs(meals, cycle: cycle, now: now))
        let today = Set(logs.filter { Calendar.current.isDate($0.day, inSameDayAs: now) }.map(\.planMealID))
        let reserved = PlanCalculator.weeklyNeeds(PlanCycle.remainingMeals(meals, eatenToday: today, now: now))
        // The list of a cycle is ready the Friday evening before it: a ticket scanned on Saturday morning belongs to it.
        let bought = Set(purchases.filter { $0.date >= PlanCycle.batchWindowStart(for: now) && $0.date < end }.map(\.ingredientID))
        return lines(meals: meals, ingredients: ingredients, checked: checked, eaten: eaten, reserved: reserved, bought: bought)
    }
}
