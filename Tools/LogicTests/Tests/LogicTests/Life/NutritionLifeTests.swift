import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// Weeks of eating with the real plan, the real meal validation, the real stock reconciliation and the real shopping list:
/// meals skipped, free weeks, holidays, shopping forgotten. What must always hold: the stock is never negative or infinite,
/// the shopping list is exactly the needs minus the stock, a meal validated twice counts once, the plan never drifts.
/// (The weight loop of `PlanAutoAdjust` needs the Health app and is covered by `PlanAutoAdjustTests`.)
@MainActor
struct NutritionHabits {
    /// A planned meal not eaten (or eaten but not validated).
    var skipMeal = 0.0
    /// Per week: nothing logged at all (trip, eating out).
    var freeWeek = 0.0
    /// Per week: the Saturday shopping is forgotten.
    var skipShopping = 0.0
    /// Validates the same meal twice (double tap).
    var doubleTap = 0.0
}

@MainActor
final class NutritionLife {
    private(set) var violations: [String] = []
    private(set) var eaten = 0
    private(set) var shoppings = 0
    private(set) var lowestStock = Double.infinity
    private let context: ModelContext
    private let container: ModelContainer
    private var dice: Dice
    private let habits: NutritionHabits
    private let calendar = Calendar.current
    private let defaults: UserDefaults

    init(habits: NutritionHabits, seed: UInt64) throws {
        container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        dice = Dice(state: seed)
        self.habits = habits
        let name = "nutrition-life-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        NutritionDefaults.seed(in: context)
    }

    func live(weeks: Int) throws {
        let meals = try context.fetch(FetchDescriptor<PlanMeal>())
        let foods = try context.fetch(FetchDescriptor<Ingredient>())
        let lookup = PlanCalculator.lookup(foods)
        let baseKcal = PlanAutoAdjust.dailyKcal(meals, lookup)
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5)) ?? .now // a Monday
        for week in 0..<weeks {
            let free = dice.chance(habits.freeWeek)
            let forgetShopping = dice.chance(habits.skipShopping)
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: week * 7 + offset, to: start) else { continue }
                let weekday = calendar.component(.weekday, from: day)
                if weekday == 7, !forgetShopping { shop(meals, foods, label: "semaine \(week + 1)") }
                if !free { eatDay(day, weekday: weekday, meals: meals, lookup: lookup) }
                let evening = day.addingTimeInterval(23 * 3_600)
                StockReconciler.run(in: context, now: evening, defaults: defaults, holidays: [])
                check(foods, label: "semaine \(week + 1), jour \(offset + 1)")
            }
        }
        let kcal = PlanAutoAdjust.dailyKcal(meals, lookup)
        if abs(kcal - baseKcal) > 400 { violations.append("plan : \(kcal - baseKcal) kcal/j de dérive sans réglage (borne ±400)") }
    }

    private func eatDay(_ day: Date, weekday: Int, meals: [PlanMeal], lookup: [UUID: Ingredient]) {
        for meal in meals where meal.weekday == weekday && !dice.chance(habits.skipMeal) {
            let at = day.addingTimeInterval(Double(8 + meal.slot.order * 3) * 3_600)
            let before = meal.items.map { lookup[$0.ingredientID]?.stockGrams ?? 0 }
            guard MealLogger.eat(meal, ingredients: lookup, in: context, now: at) != nil else {
                violations.append("repas \(meal.slot.label) refusé alors qu'il n'avait pas été validé ce jour")
                continue
            }
            eaten += 1
            for (item, was) in zip(meal.items, before) where abs((lookup[item.ingredientID]?.stockGrams ?? 0) - max(0, was - item.grams)) > 1e-6 {
                violations.append("stock de \(lookup[item.ingredientID]?.name ?? "?") : \(was) − \(item.grams) g mal retiré")
            }
            if dice.chance(habits.doubleTap), MealLogger.eat(meal, ingredients: lookup, in: context, now: at) != nil {
                violations.append("repas \(meal.slot.label) compté deux fois")
            }
        }
    }

    /// Buys what the list says, then checks the list is exactly needs − stock before and empty after.
    private func shop(_ meals: [PlanMeal], _ foods: [Ingredient], label: String) {
        let lines = ShoppingList.lines(meals: meals, ingredients: foods, checked: [])
        for line in lines {
            let expected = max(0, line.need - line.food.stockGrams)
            if abs(line.toBuy - expected) > 1e-6 { violations.append("\(label) : courses \(line.food.name) \(line.toBuy) g au lieu de besoin − stock = \(expected)") }
            if line.toBuy < 0 || !line.toBuy.isFinite { violations.append("\(label) : courses \(line.food.name) invalides (\(line.toBuy))") }
            line.food.stockGrams += line.packs > 0 ? Double(line.packs) * line.food.packGrams : line.toBuy
        }
        for line in ShoppingList.lines(meals: meals, ingredients: foods, checked: []) where line.toBuy > max(1e-6, 0.02 * line.food.packGrams) {  // < 2 % of a pack short is tolerated (ShoppingList)
            violations.append("\(label) : après les courses il manque encore \(line.toBuy) g de \(line.food.name)")
        }
        shoppings += 1
    }

    private func check(_ foods: [Ingredient], label: String) {
        for food in foods {
            lowestStock = min(lowestStock, food.stockGrams)
            if !food.stockGrams.isFinite || food.stockGrams < 0 { violations.append("\(label) : stock de \(food.name) = \(food.stockGrams)") }
        }
    }
}

@Suite(.serialized) struct NutritionLifeTests {
    @MainActor private func live(_ name: String, weeks: Int, _ habits: NutritionHabits) throws -> [NutritionLife] {
        try LifeTests.seeds.map { seed in
            let life = try NutritionLife(habits: habits, seed: seed)
            try life.live(weeks: weeks)
            print("life · \(name) · graine \(seed) : \(life.eaten) repas validés, \(life.shoppings) courses, stock mini \(Int(life.lowestStock)) g")
            if !life.violations.isEmpty {
                let lines = Set(life.violations).sorted().prefix(12).map { "  \($0)" }
                Issue.record("\(name) · graine \(seed) :\n\(lines.joined(separator: "\n"))")
            }
            return life
        }
    }

    @Test @MainActor func steadyEater() throws {
        for life in try live("Alimentation régulière", weeks: 12, NutritionHabits()) {
            #expect(life.eaten > 12 * 7 * 4)
            #expect(life.shoppings == 12)
        }
    }

    @Test @MainActor func messyEater() throws {
        let habits = NutritionHabits(skipMeal: 0.25, freeWeek: 0.15, skipShopping: 0.2, doubleTap: 0.1)
        _ = try live("Alimentation désordonnée", weeks: 16, habits)
    }
}
