import Foundation
import SwiftData

/// First-launch nutrition data: the foods, the weekly plan and the Sunday batch cooking steps.
enum NutritionDefaults {
    private struct Food {
        var key: String, name: String, emoji: String, category: String
        var kcal: Double, protein: Double, carbs: Double, fat: Double
        var pieceGrams = 0.0, pieceLabel = "", packGrams = 0.0
    }

    private static let foods: [Food] = [
        Food(key: "egg", name: "Œufs", emoji: "🥚", category: "Frais", kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, pieceGrams: 60, pieceLabel: "œuf", packGrams: 720),
        Food(key: "bread", name: "Pain complet au levain", emoji: "🍞", category: "Boulangerie", kcal: 250, protein: 9, carbs: 46, fat: 1.5, packGrams: 750),
        Food(key: "oats", name: "Flocons d'avoine", emoji: "🌾", category: "Épicerie", kcal: 370, protein: 13, carbs: 60, fat: 7, packGrams: 1000),
        Food(key: "fb", name: "Fromage blanc 0 %", emoji: "🥛", category: "Frais", kcal: 46, protein: 8, carbs: 4, fat: 0.2, packGrams: 960),
        Food(key: "almonds", name: "Amandes", emoji: "🥜", category: "Épicerie", kcal: 580, protein: 21, carbs: 6, fat: 52, packGrams: 100),
        Food(key: "banana", name: "Bananes", emoji: "🍌", category: "Fruits", kcal: 90, protein: 1, carbs: 20, fat: 0.3, pieceGrams: 100, pieceLabel: "banane"),
        Food(key: "pasta", name: "Pâtes complètes", emoji: "🍝", category: "Épicerie", kcal: 350, protein: 13, carbs: 66, fat: 2.5, packGrams: 500),
        Food(key: "rice", name: "Riz basmati", emoji: "🍚", category: "Épicerie", kcal: 350, protein: 8.5, carbs: 77, fat: 0.8, packGrams: 1000),
        Food(key: "steak", name: "Steak haché 5 %", emoji: "🥩", category: "Frais", kcal: 125, protein: 21, carbs: 0, fat: 5),
        Food(key: "chicken", name: "Poulet filet", emoji: "🍗", category: "Frais", kcal: 110, protein: 23, carbs: 0, fat: 1.5),
        Food(key: "tuna", name: "Thon naturel", emoji: "🐟", category: "Conserves", kcal: 110, protein: 25, carbs: 0, fat: 1, pieceGrams: 113, pieceLabel: "boîte", packGrams: 339),
        Food(key: "sardines", name: "Sardines à l'huile", emoji: "🐟", category: "Conserves", kcal: 210, protein: 24, carbs: 0, fat: 12, pieceGrams: 80, pieceLabel: "boîte", packGrams: 80),
        Food(key: "beans", name: "Haricots verts surgelés", emoji: "🫛", category: "Surgelés", kcal: 30, protein: 2, carbs: 4.5, fat: 0.2, packGrams: 1000),
        Food(key: "rata", name: "Ratatouille surgelée", emoji: "🍆", category: "Surgelés", kcal: 40, protein: 1, carbs: 5, fat: 1.7, packGrams: 750),
        Food(key: "sauce", name: "Sauce Panzani", emoji: "🍅", category: "Épicerie", kcal: 50, protein: 1.5, carbs: 8, fat: 1.5, packGrams: 650),
        Food(key: "oil", name: "Huile d'olive", emoji: "🫒", category: "Épicerie", kcal: 884, protein: 0, carbs: 0, fat: 100, packGrams: 920),
    ]

    /// "weekday|meal|food grams, …" — weekday follows `Calendar` (2 = Monday … 1 = Sunday).
    private static let mainMeals = """
    2|breakfast|egg 240, bread 75, oil 5
    2|lunch|pasta 110, steak 100, beans 200, sauce 150, oil 10, fb 100
    2|dinner|rice 100, chicken 150, rata 250, sauce 150, oil 5
    3|breakfast|egg 240, bread 75, oil 5
    3|lunch|rice 110, chicken 150, beans 200, sauce 150, oil 10, fb 100
    3|dinner|pasta 100, steak 100, rata 250, sauce 150, oil 5
    4|breakfast|egg 240, bread 75
    4|lunch|rice 110, chicken 150, beans 200, sauce 150, oil 10, fb 100
    4|dinner|pasta 105, sardines 80, rata 250, sauce 150, oil 5
    5|breakfast|egg 240, bread 75
    5|lunch|pasta 110, tuna 113, beans 200, sauce 150, oil 10, fb 100
    5|dinner|rice 110, sardines 80, rata 250, sauce 150, oil 5
    6|breakfast|egg 240, bread 75, oil 5
    6|lunch|rice 120, sardines 80, beans 200, sauce 150, oil 5, fb 100
    6|dinner|pasta 105, steak 100, rata 250, sauce 150, oil 5
    7|breakfast|egg 240, bread 75, banana 100
    7|lunch|pasta 100, chicken 150, beans 200, sauce 150, oil 5, fb 100
    7|dinner|rice 80, egg 240, rata 250, sauce 150
    1|breakfast|egg 240, bread 75, oil 5
    1|lunch|pasta 120, chicken 150, beans 200, sauce 150, oil 10, fb 100
    1|dinner|pasta 110, steak 100, rata 250, sauce 150
    """

    private static let dailySnack = "oats 75, fb 250, almonds 10, banana 100"
    private static let dailyEvening = "fb 200"

    private static let batchSteps: [(title: String, detail: String, seconds: Int)] = [
        ("Riz", "Rincer 550 g de riz basmati ×3.\nDans le cuiseur : 580 g de riz, 950 g d'eau, 5 g de sel. Lancer la cuisson.\nÀ la fin : aérer à la fourchette, laisser ouvert. Pas de maintien au chaud.", 0),
        ("Eau et barbecue", "4 L d'eau + 40 g de gros sel, couvrir, feu maximum.\nPréchauffer le barbecue.", 0),
        ("Ratatouille · fournée 1", "Poêle large, feu vif : 625 g de ratatouille surgelée, 10–12 min à découvert, en remuant.", 660),
        ("Ratatouille · fournée 2", "Même chose avec les 625 g restants.", 660),
        ("Pâtes", "535 g de pâtes, temps du paquet − 3 min. Égoutter, rincer 30 s à l'eau froide, bien égoutter.\nSous-cuisson voulue : le réchauffage finira la cuisson.", 0),
        ("Poulet au barbecue", "Sécher le poulet très soigneusement.\nBarbecue très chaud : 2 min par face, un seul retournement, ne pas écraser.\nJuste cuit, à peine nacré au centre. Verser le jus dessus.", 240),
        ("Haricots verts · fournée 1", "Feu vif : 500 g de haricots surgelés, 8–10 min à découvert.", 540),
        ("Haricots verts · fournée 2", "Même chose avec 500 g. Deux fournées pour qu'ils sautent au lieu de bouillir.", 540),
        ("Steaks", "3 steaks de 100 g, environ 2 cm d'épaisseur.\nPoêle bien chaude, 1 min 15 par face, rosés à cœur.", 75),
        ("Refroidissement", "10–15 min à découvert, puis fermer les boîtes et mettre au réfrigérateur.", 750),
    ]

    static func seed(in context: ModelContext) {
        dropBrine(in: context)
        fixSaucePack(in: context)
        fixBreadPrice(in: context)
        fixTunaPack(in: context)
        guard (try? context.fetchCount(FetchDescriptor<Ingredient>())) == 0 else { return }
        var byKey: [String: Ingredient] = [:]
        for f in foods {
            let food = Ingredient(
                name: f.name, emoji: f.emoji, category: f.category, kcal: f.kcal, protein: f.protein, carbs: f.carbs,
                fat: f.fat, pieceGrams: f.pieceGrams, pieceLabel: f.pieceLabel, packGrams: f.packGrams
            )
            context.insert(food)
            byKey[f.key] = food
        }
        for line in mainMeals.split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 3, let weekday = Int(parts[0]), let slot = MealSlot(rawValue: String(parts[1])) else { continue }
            context.insert(PlanMeal(weekday: weekday, slot: slot, items: items(String(parts[2]), byKey)))
        }
        for weekday in 1...7 {
            context.insert(PlanMeal(weekday: weekday, slot: .snack, items: items(dailySnack, byKey)))
            context.insert(PlanMeal(weekday: weekday, slot: .evening, items: items(dailyEvening, byKey)))
        }
        for (index, step) in batchSteps.enumerated() {
            context.insert(BatchStep(order: index, title: step.title, detail: step.detail, timerSeconds: step.seconds))
        }
        context.saveReportingFailure()
    }

    /// A jar of the sauce is 650 g, not the 400 g first seeded (2026-10-31): a store seeded before is corrected once.
    static func fixSaucePack(in context: ModelContext) {
        let foods = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        guard let sauce = foods.first(where: { $0.name == "Sauce Panzani" && $0.packGrams == 400 }) else { return }
        sauce.packGrams = 650
        context.saveReportingFailure()
    }

    /// Tuna is bought by 3 cans (2026-10-31) and counted in cans: the pack becomes 3 cans (and its price × 3), once.
    static func fixTunaPack(in context: ModelContext) {
        let foods = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        guard let tuna = foods.first(where: { $0.name == "Thon naturel" && $0.packGrams == $0.pieceGrams && $0.pieceGrams > 0 }) else { return }
        tuna.packGrams = tuna.pieceGrams * 3
        tuna.packPrice *= 3
        context.saveReportingFailure()
    }

    /// A sourdough loaf costs about 2.60 € at the bakery (5.20 € for two, 2026-10-31); the price is set once when none was typed.
    static func fixBreadPrice(in context: ModelContext) {
        let foods = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        guard let bread = foods.first(where: { $0.category == ShoppingList.bakery && $0.packPrice == 0 }) else { return }
        bread.packPrice = 2.6
        context.saveReportingFailure()
    }

    /// The brine step is gone for good (2026-10-30): removed from a store seeded before, with its mention in the chicken step.
    static func dropBrine(in context: ModelContext) {
        let steps = (try? context.fetch(FetchDescriptor<BatchStep>())) ?? []
        guard let brine = steps.first(where: { $0.title.hasPrefix("Saumure") }) else { return }
        context.delete(brine)
        for step in steps where step.detail.hasPrefix("Sortir le poulet, rincer, sécher") {
            step.detail = step.detail.replacingOccurrences(of: "Sortir le poulet, rincer, sécher", with: "Sécher le poulet")
        }
        context.saveReportingFailure()
    }

    private static func items(_ text: String, _ byKey: [String: Ingredient]) -> [PlanItem] {
        text.split(separator: ",").compactMap { part in
            let words = part.split(separator: " ")
            guard words.count == 2, let food = byKey[String(words[0])], let grams = Double(words[1]) else { return nil }
            return PlanItem(ingredientID: food.id, grams: grams)
        }
    }
}
