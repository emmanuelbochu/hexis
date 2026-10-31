import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// A food of 100 kcal and 10 g of protein per 100 g, so grams read as kcal.
private func food(carbs: Double = 0, kcal: Double = 100) -> Ingredient {
    Ingredient(name: "Test", emoji: "x", category: "Épicerie", kcal: kcal, protein: 10, carbs: carbs, fat: 0)
}

private let calendar = Calendar.current
private func date(_ day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
}
private func weekday(_ day: Int) -> Int { calendar.component(.weekday, from: date(day)) }

@Suite struct DailyIntakeTests {
    // Past day 4 Nov: plan = breakfast 200, lunch 300, dinner 400 kcal.
    let egg = food()
    var meals: [PlanMeal] {
        [PlanMeal(weekday: weekday(4), slot: .breakfast, items: [PlanItem(ingredientID: egg.id, grams: 200)]),
         PlanMeal(weekday: weekday(4), slot: .lunch, items: [PlanItem(ingredientID: egg.id, grams: 300)]),
         PlanMeal(weekday: weekday(4), slot: .dinner, items: [PlanItem(ingredientID: egg.id, grams: 400)])]
    }
    func entry(_ slot: MealSlot, _ kcal: Int, day: Int = 4) -> FoodEntry {
        FoodEntry(date: date(day, hour: 9), meal: slot, name: "x", kcal: kcal, protein: 0, carbs: 0, fat: 0)
    }

    @Test func pastDayWithOnlyBreakfastLoggedAssumesTheRest() {
        let total = DailyIntake.macros(on: date(4), entries: [entry(.breakfast, 150)], meals: meals, ingredients: PlanCalculator.lookup([egg]), now: date(10))
        #expect(total.kcal == 150 + 300 + 400)
    }

    @Test func todayCountsOnlyPastSlots() {
        // 14:00 = lunch slot: breakfast is gone (assumed), lunch and dinner still to come.
        let total = DailyIntake.macros(on: date(4), entries: [], meals: meals, ingredients: PlanCalculator.lookup([egg]), now: date(4, hour: 14))
        #expect(total.kcal == 200)
    }

    @Test func futureDayCountsNothingPlanned() {
        let total = DailyIntake.macros(on: date(4), entries: [], meals: meals, ingredients: PlanCalculator.lookup([egg]), now: date(2))
        #expect(total.kcal == 0)
    }

    @Test func aReplacedSlotIsNotCountedTwice() {
        let total = DailyIntake.macros(on: date(4), entries: [entry(.lunch, 900)], meals: meals, ingredients: PlanCalculator.lookup([egg]), now: date(10))
        #expect(total.kcal == 900 + 200 + 400)
    }

    @Test func onlyTrackedDaysCount() {
        let few = [entry(.breakfast, 100), entry(.lunch, 100)]
        let enough = [entry(.breakfast, 100, day: 5), entry(.lunch, 100, day: 5), entry(.dinner, 100, day: 5)]
        let days = DailyIntake.byDay(entries: few + enough, meals: [], ingredients: [:], since: date(1), now: date(10))
        #expect(days.count == 1)
        #expect(days[calendar.startOfDay(for: date(5))]?.kcal == 300)
    }

    @Test func meanNeedsFiveDays() {
        var intake: [Date: Macros] = [:]
        for d in 1...4 { intake[calendar.startOfDay(for: date(d))] = Macros(kcal: 2000) }
        #expect(DailyIntake.mean(intake, from: date(1), now: date(10)) { Double($0.kcal) } == nil)
        intake[calendar.startOfDay(for: date(5))] = Macros(kcal: 3000)
        #expect(DailyIntake.mean(intake, from: date(1), now: date(10)) { Double($0.kcal) } == 2200)
    }
}

@Suite struct PhaseCheckTests {
    private func slope(_ kg: Double, kcal: Int? = nil, protein: Double? = nil) -> BodyInsights.Slope {
        .init(kgPerWeek: kg, weighIns: 8, kcalPerDay: kcal, proteinPerDay: protein)
    }
    private let range = 125.0...170.0

    @Test func onTrackMovesNothing() {
        let check = PhaseCheck.make(goal: .bulk, slope: slope(0.15), proteinRange: range)
        #expect(check?.verdict == .onTrack)
        #expect(check?.kcalDelta == 0)
    }

    @Test func flatWeightAddsOneStepOnly() {
        let check = PhaseCheck.make(goal: .bulk, slope: slope(0.0), proteinRange: range)
        #expect(check?.verdict == .tooSlow)
        #expect(check?.kcalDelta == 150)
    }

    @Test func fastGainRemovesOneStepOnly() {
        let check = PhaseCheck.make(goal: .bulk, slope: slope(0.8), proteinRange: range)
        #expect(check?.verdict == .tooFast)
        #expect(check?.kcalDelta == -150)
    }

    @Test func slightlyOffGetsASmallStep() {
        // 0.05 kg/week: the middle of the range (0.15) is 0.10 kg/week away = 110 kcal/day, to the nearest 50.
        #expect(PhaseCheck.make(goal: .bulk, slope: slope(0.05), proteinRange: range)?.kcalDelta == 100)
    }

    @Test func lowProteinBeatsMaintenanceLine() {
        let check = PhaseCheck.make(goal: .bulk, slope: slope(0.15, kcal: 2800, protein: 90), proteinRange: range)
        #expect(check?.detail?.contains("Protéines 90") == true)
    }

    @Test func maintenanceIsIntakeMinusTheGain() {
        let check = PhaseCheck.make(goal: .bulk, slope: slope(0.15, kcal: 2800, protein: 170), proteinRange: range)
        #expect(check?.detail == "Ta maintenance est d'environ 2600 kcal/j (tu manges 2800).")
    }

    @Test func noSlopeNoCheck() {
        #expect(PhaseCheck.make(goal: .bulk, slope: nil, proteinRange: range) == nil)
    }

    @Test func slopeFromWeighIns() {
        let start = date(1)
        let weights = (0..<6).map { HealthService.Day(date: start.addingTimeInterval(Double($0) * 3 * 86_400), value: 75 + 0.3 * Double($0) * 3 / 7) }
        let result = BodyInsights.slope(weights: weights, intake: [:], now: date(20))
        #expect(abs((result?.kgPerWeek ?? 0) - 0.3) < 0.01)
        #expect(result?.kcalPerDay == nil)
        // Under 14 days of spread there is no slope.
        #expect(BodyInsights.slope(weights: Array(weights.prefix(4)), intake: [:], now: date(20)) == nil)
    }
}

@Suite struct NextMealPickerTests {
    private func plan(_ slots: [MealSlot]) -> [PlanMeal] { slots.map { PlanMeal(weekday: 4, slot: $0, items: []) } }
    private let all: [MealSlot] = [.breakfast, .lunch, .snack, .dinner, .evening]

    @Test func showsTheCurrentSlot() {
        let meals = plan(all)
        #expect(NextMealPicker.pick(meals: meals, doneIDs: [], weekday: 4, hour: 12)?.slot == .lunch)
        #expect(NextMealPicker.pick(meals: meals, doneIDs: [], weekday: 4, hour: 19)?.slot == .dinner)
    }

    @Test func skipsAFinishedSlotToTheNextOne() {
        let meals = plan(all)
        let lunch = Set([meals[1].id])
        #expect(NextMealPicker.pick(meals: meals, doneIDs: lunch, weekday: 4, hour: 12)?.slot == .snack)
    }

    @Test func aForgottenMealDoesNotBlockTheRest() {
        // 20:00, breakfast and lunch never validated: the dinner is shown.
        #expect(NextMealPicker.pick(meals: plan(all), doneIDs: [], weekday: 4, hour: 20)?.slot == .dinner)
    }

    @Test func nothingLeftMeansNil() {
        let meals = plan(all)
        #expect(NextMealPicker.pick(meals: meals, doneIDs: Set(meals.map(\.id)), weekday: 4, hour: 22) == nil)
        #expect(NextMealPicker.pick(meals: meals, doneIDs: [], weekday: 5, hour: 12) == nil)
    }
}

@Suite struct PlanAutoAdjustTests {
    let rice = food(carbs: 77, kcal: 350)
    let egg = food(carbs: 0.7, kcal: 143)
    private func plan() -> [PlanMeal] {
        [PlanMeal(weekday: 2, slot: .lunch, items: [PlanItem(ingredientID: rice.id, grams: 100), PlanItem(ingredientID: egg.id, grams: 100)]),
         PlanMeal(weekday: 2, slot: .dinner, items: [PlanItem(ingredientID: rice.id, grams: 100)])]
    }

    @Test func movesTheCaloriesByAboutTheStepAndOnlyTheStarch() {
        let meals = plan()
        let foods = PlanCalculator.lookup([rice, egg])
        let before = PlanCalculator.macros(of: meals, ingredients: foods)
        PlanAutoAdjust.apply(kcalPerDay: 150, to: meals, foods: foods)
        let after = PlanCalculator.macros(of: meals, ingredients: foods)
        #expect(abs(after.kcal - before.kcal - 150) <= 25)
        #expect(meals[0].items[1].grams == 100)
        #expect(meals[0].items[0].grams.truncatingRemainder(dividingBy: 5) == 0)
    }

    @Test func neverScalesBelowSeventyPercent() {
        let meals = plan()
        PlanAutoAdjust.apply(kcalPerDay: -5000, to: meals, foods: PlanCalculator.lookup([rice, egg]))
        #expect(meals[0].items[0].grams == 70)
    }

    @Test func aDayWithoutStarchIsLeftAlone() {
        let meals = [PlanMeal(weekday: 3, slot: .lunch, items: [PlanItem(ingredientID: egg.id, grams: 240)])]
        PlanAutoAdjust.apply(kcalPerDay: 150, to: meals, foods: PlanCalculator.lookup([rice, egg]))
        #expect(meals[0].items[0].grams == 240)
    }

    @Test func batchRiceAndPastaFollowTheScale() {
        let rice = BatchStep(order: 1, title: "Riz", detail: "Rincer 550 g de riz basmati ×3.\nDans le cuiseur : 580 g de riz, 950 g d'eau, 5 g de sel.")
        let pasta = BatchStep(order: 2, title: "Pâtes", detail: "535 g de pâtes, temps du paquet − 3 min.")
        let chicken = BatchStep(order: 3, title: "Poulet", detail: "450 g de filets de poulet, 30 g de sel.")
        #expect(BatchScaling.detail(of: rice, scale: 1.2) == "Rincer 660 g de riz basmati ×3.\nDans le cuiseur : 695 g de riz, 1140 g d'eau, 5 g de sel.")
        #expect(BatchScaling.detail(of: pasta, scale: 1.2) == "640 g de pâtes, temps du paquet − 3 min.")
        #expect(BatchScaling.detail(of: chicken, scale: 1.2) == chicken.detail)
        #expect(BatchScaling.detail(of: rice, scale: 1) == rice.detail)
    }
}

@Suite struct StockReconcilerTests {
    // Plan: 200 g of egg every day, one meal (lunch). The stock starts at 1 000 g. Today is 10 Nov.
    static func setUp(logged days: [Int]) throws -> (ModelContext, Ingredient) {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let egg = Ingredient(name: "Oeuf", emoji: "x", category: "Épicerie", kcal: 100, protein: 10, carbs: 0, fat: 0, stockGrams: 1000)
        context.insert(egg)
        for weekday in 1...7 { context.insert(PlanMeal(weekday: weekday, slot: .lunch, items: [PlanItem(ingredientID: egg.id, grams: 200)])) }
        // An ordinary day: breakfast, dinner and a lunch eaten out (the plan's lunch is replaced, so it is not taken from the stock).
        for day in days {
            for slot in [MealSlot.breakfast, .lunch, .dinner] { context.insert(FoodEntry(date: date(day), meal: slot, name: "x", kcal: 0, protein: 0, carbs: 0, fat: 0)) }
        }
        return (context, egg)
    }
    private func reconcile(_ context: ModelContext, from last: Int, holidays: [SchoolHoliday] = []) {
        let defaults = UserDefaults(suiteName: "stock-\(UUID().uuidString)") ?? .standard
        defaults.set(date(last), forKey: "stockReconciledOn")
        StockReconciler.run(in: context, now: date(10), defaults: defaults, holidays: holidays)
    }

    @Test func missedMealsOfOrdinaryDaysAreTakenFromTheStock() throws {
        // 7 and 8 Nov: nothing logged, but 5, 6 and 9 were lived normally around them: a short gap, not a holiday.
        let (context, egg) = try Self.setUp(logged: [5, 6, 9])
        reconcile(context, from: 6)
        #expect(egg.stockGrams == 1000 - 2 * 200)
    }

    @Test func aHolidayOfThreeDaysWithoutLoggingLeavesTheStockAlone() throws {
        let (context, egg) = try Self.setUp(logged: [])
        reconcile(context, from: 6)
        #expect(egg.stockGrams == 1000)
    }
}

@Suite struct FreePeriodTests {
    private let holiday = SchoolHoliday(name: "vacances de test", start: date(7), end: date(9))

    @Test func holidayDaysAreFreeEvenWhenLogged() {
        let day = { calendar.startOfDay(for: date($0)) }
        let free = FreePeriod.freeDays([day(6): 3, day(7): 3, day(8): 3, day(10): 3], holidays: [holiday])
        #expect(free == [day(7), day(8)])
    }

    @Test func aCycleMostlyInHolidayIsFlagged() {
        let monday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        let week = SchoolHoliday(name: "x", start: calendar.date(from: DateComponents(year: 2026, month: 11, day: 3))!, end: calendar.date(from: DateComponents(year: 2026, month: 11, day: 8))!)
        #expect(FreePeriod.isHolidayCycle(monday, holidays: [week]))
        #expect(!FreePeriod.isHolidayCycle(monday, holidays: [holiday]))
    }

    @Test func schoolHolidayDaysAreNeverTakenFromTheStock() throws {
        let (context, egg) = try StockReconcilerTests.setUp(logged: [5, 6, 9])
        let defaults = UserDefaults(suiteName: "free-\(UUID().uuidString)") ?? .standard
        defaults.set(date(6), forKey: "stockReconciledOn")
        // 7 Nov is a holiday day: left alone from its first day; 8 Nov is an ordinary missed day (a 2-day gap is no holiday).
        StockReconciler.run(in: context, now: date(10), defaults: defaults, holidays: [SchoolHoliday(name: "x", start: date(7), end: date(7))])
        #expect(egg.stockGrams == 1000 - 200)
    }

    @Test func theScaleStaysQuietDuringAndAfterAHoliday() throws {
        let (context, _) = try StockReconcilerTests.setUp(logged: [5, 6, 7, 8, 9] + Array(13...19))
        #expect(FreePeriod.pausesAdjustment(in: context, now: date(10), holidays: [holiday]))
        #expect(!FreePeriod.pausesAdjustment(in: context, now: date(20), holidays: [holiday]))
    }
}

@Suite struct ShoppingHabitsTests {
    @Test func packSizeIsLearnedFromMultiplesOfTheSmallestPurchase() {
        #expect(UsualPack.size(from: [500, 1000, 1500, 500]) == 500)
        #expect(UsualPack.size(from: [480, 960, 480]) == 480)
    }

    @Test func aFoodAlwaysBoughtInTheSameQuantityKeepsItsPack() {
        #expect(UsualPack.size(from: [1500, 1500, 1500]) == nil)
        #expect(UsualPack.size(from: [500, 730, 910]) == nil)
        #expect(UsualPack.size(from: [500, 1000]) == nil)
    }

    @Test func theListIsReadyOnFridayEvening() {
        func monday(_ day: Int, _ hour: Int) -> Date { PlanCycle.start(for: date(day, hour: hour)) }
        // Nov 2026: the 6th is a Friday.
        #expect(monday(6, 17) == calendar.startOfDay(for: date(2)))
        #expect(monday(6, 18) == calendar.startOfDay(for: date(9)))
        #expect(monday(8, 12) == calendar.startOfDay(for: date(9)))
        #expect(monday(9, 8) == calendar.startOfDay(for: date(9)))
        #expect(PlanCycle.nextListReady(after: date(6, hour: 19)) == date(13, hour: 18).startOfHour(18, in: PlanCycle.calendar))
    }

    @Test func fromFridayEveningTheWeekendMealsStayReservedInTheStock() {
        let meals = (1...7).map { PlanMeal(weekday: $0, slot: .lunch, items: []) }
        let left = PlanCycle.remainingMeals(meals, eatenToday: [], now: date(6, hour: 19))
        #expect(Set(left.map(\.weekday)) == [6, 7, 1])
        let eaten = PlanCycle.remainingMeals(meals, eatenToday: [meals[5].id], now: date(6, hour: 19))
        #expect(Set(eaten.map(\.weekday)) == [7, 1])
    }

    @Test func weekendStaplesGetASmallMargin() {
        let chicken = Ingredient(name: "Poulet filet", emoji: "x", category: "Frais", kcal: 110, protein: 23, carbs: 0, fat: 1.5)
        let steak = Ingredient(name: "Steak haché 5 %", emoji: "x", category: "Frais", kcal: 125, protein: 21, carbs: 0, fat: 5)
        let meals = [
            PlanMeal(weekday: 7, slot: .lunch, items: [PlanItem(ingredientID: chicken.id, grams: 150), PlanItem(ingredientID: steak.id, grams: 100)]),
            PlanMeal(weekday: 3, slot: .lunch, items: [PlanItem(ingredientID: chicken.id, grams: 150)]),
        ]
        let extra = GuestMargin.extra(meals: meals, ingredients: [chicken, steak])
        #expect(extra[chicken.id] == 30)
        #expect(extra[steak.id] == nil)
    }

    @Test func breadIsBoughtAsWholeLoaves() {
        let bread = Ingredient(name: "Pain au levain", emoji: "x", category: "Boulangerie", kcal: 250, protein: 9, carbs: 46, fat: 1.5, packGrams: 750)
        let line = ShoppingLine(food: bread, need: 750, toBuy: 750, packs: 1, cost: 0, checked: false)
        #expect(line.buyText == "1 miche")
        let two = ShoppingLine(food: bread, need: 1500, toBuy: 1500, packs: 2, cost: 5.2, checked: false)
        #expect(two.buyText == "2 miches" && ShoppingList.portions(for: two) == 5)
    }

    @Test func packsAreShownAsTheUsualPurchase() {
        let pasta = Ingredient(name: "Pâtes", emoji: "x", category: "Épicerie", kcal: 350, protein: 13, carbs: 66, fat: 2.5, packGrams: 500)
        #expect(ShoppingLine(food: pasta, need: 1400, toBuy: 1400, packs: 3, cost: 0, checked: false).buyText == "3 × 500 g")
    }

    @Test func aHabitualExtraIsRemindedWhenItsRhythmIsDue() {
        func buy(_ day: Int) -> ExtraPurchase { ExtraPurchase(label: "Yaourt Grec", category: "Frais", price: 2.5, date: date(day)) }
        let weekly = [buy(1), buy(8), buy(15)]
        #expect(UsualExtras.due(weekly, now: date(21)).map(\.label) == ["Yaourt Grec"])
        #expect(UsualExtras.due(weekly, now: date(16)).isEmpty)
        #expect(UsualExtras.due([buy(1), buy(8)], now: date(21)).isEmpty)
        #expect(UsualExtras.due(weekly, now: date(80)).isEmpty)
    }
}

private extension Date {
    func startOfHour(_ hour: Int, in calendar: Calendar) -> Date { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: self) ?? self }
}

@Suite struct GeminiRetryTests {
    @Test func overloadAnswersAreRetriedOthersAreNot() {
        for code in [429, 500, 502, 503, 504] { #expect(GeminiClient.isOverload(code)) }
        for code in [200, 400, 401, 403, 404] { #expect(!GeminiClient.isOverload(code)) }
        #expect(GeminiClient.retryDelays.count == 2)
        #expect(GeminiClient.retryDelays.reduce(0, +) <= 10)
        #expect(GeminiClient.GeminiError.http(503).errorDescription?.contains("surchargé") == true)
    }
}

@Suite struct ReceiptResolverTests {
    private let sauce = Ingredient(name: "Sauce", emoji: "x", category: "Épicerie", kcal: 50, protein: 1, carbs: 8, fat: 1, packGrams: 650)
    private let tuna = Ingredient(name: "Thon", emoji: "x", category: "Épicerie", kcal: 100, protein: 25, carbs: 0, fat: 1, pieceGrams: 112, pieceLabel: "boîte")

    private func answer(_ lines: [(Int, Double, Double, String)]) throws -> Data {
        let m = lines.map { ["i": $0.0, "g": $0.1, "p": $0.2, "t": $0.3] as [String: Any] }
        return try JSONSerialization.data(withJSONObject: ["m": m, "x": []])
    }

    @Test func thePromptGivesTheUsualPackAndTheTaughtLines() {
        let off = ReceiptAlias(label: "odyssee maqx nature", ingredientID: ReceiptResolver.offPlan)
        let toSauce = ReceiptAlias(label: "panzani sce provenca", ingredientID: sauce.id)
        let prompt = ReceiptResolver.prompt(foods: [sauce, tuna], aliases: [off, toSauce])
        #expect(prompt.contains("0|Sauce|p650"))
        #expect(prompt.contains("1|Thon|u112"))
        #expect(prompt.contains("« odyssee maqx nature » = hors liste"))
        #expect(prompt.contains("« panzani sce provenca » = 0"))
    }

    @Test func aLineTaughtAsOutOfThePlanGoesToTheSpending() throws {
        let off = ReceiptAlias(label: "ODYSSEE MAQX NATURE", ingredientID: ReceiptResolver.offPlan)
        let data = try answer([(1, 336, 1.74, "ODYSSEE MAQX NATURE"), (0, 650, 2.18, "PANZANI SCE PROVENCA")])
        let result = try ReceiptResolver.resolve(data, foods: [sauce, tuna], aliases: [off])
        #expect(result.matches.map(\.food.name) == ["Sauce"])
        #expect(result.extras.map(\.label) == ["ODYSSEE MAQX NATURE"])
        #expect(result.extras.first?.price == 1.74)
    }

    @Test func aTaughtFoodBeatsTheAIGuess() throws {
        let taught = ReceiptAlias(label: "PANZANI SCE PROVENCA", ingredientID: sauce.id)
        let data = try answer([(1, 500, 2.18, "PANZANI SCE PROVENCA")])
        let result = try ReceiptResolver.resolve(data, foods: [sauce, tuna], aliases: [taught])
        #expect(result.matches.map(\.food.name) == ["Sauce"])
        #expect(result.extras.isEmpty)
    }

    @Test func withoutTeachingTheAIAnswerIsKept() throws {
        let result = try ReceiptResolver.resolve(try answer([(1, 336, 1.74, "ODYSSEE MAQX NATURE")]), foods: [sauce, tuna])
        #expect(result.matches.first?.food.name == "Thon")
    }
}

@Suite struct ReceiptQuantityTests {
    private let sauce = Ingredient(name: "Sauce", emoji: "x", category: "Épicerie", kcal: 50, protein: 1, carbs: 8, fat: 1, packGrams: 650)
    private let tuna = Ingredient(name: "Thon", emoji: "x", category: "Épicerie", kcal: 100, protein: 25, carbs: 0, fat: 1, pieceGrams: 112, pieceLabel: "boîte")

    @Test func severalPacksShowTheCountAndTheSizeOfOnePack() {
        #expect(ReceiptMatch(food: sauce, grams: 1950, price: 6, units: 3).quantityText == "3 × 650 g")
        #expect(ReceiptMatch(food: sauce, grams: 650, price: 2, units: 1).quantityText == "650 g")
        #expect(ReceiptMatch(food: sauce, grams: 1300, price: 4, units: nil).quantityText == "1,3 kg")
        #expect(ReceiptMatch(food: tuna, grams: 336, price: 5, units: 3).quantityText == "3 boîtes")
    }

    @Test func theCountComesFromTheTicketAndAddsUpForTheSameFood() throws {
        let rows: [[String: Any]] = [["i": 0, "g": 1300, "p": 4.0, "t": "A", "n": 2], ["i": 0, "g": 650, "p": 2.0, "t": "B", "n": 1]]
        let data = try JSONSerialization.data(withJSONObject: ["m": rows, "x": []])
        let match = try #require(try ReceiptResolver.resolve(data, foods: [sauce]).matches.first)
        #expect(match.units == 3 && match.grams == 1950)
        #expect(match.quantityText == "3 × 650 g")
        let unknown = try JSONSerialization.data(withJSONObject: ["m": [["i": 0, "g": 650, "p": 2.0, "t": "A"]], "x": []])
        #expect(try ReceiptResolver.resolve(unknown, foods: [sauce]).matches.first?.units == nil)
    }
}

@Suite struct ReceiptTotalTests {
    private let sauce = Ingredient(name: "Sauce", emoji: "x", category: "Épicerie", kcal: 50, protein: 1, carbs: 8, fat: 1, packGrams: 650)

    @Test func theUnexplainedPartOfTheTotalCountsAsSpending() throws {
        let rows: [[String: Any]] = [["i": 0, "g": 650, "p": 2.0, "t": "A", "n": 1]]
        let extra: [[String: Any]] = [["t": "Cola", "p": 3.0, "c": "Boisson"]]
        let data = try JSONSerialization.data(withJSONObject: ["m": rows, "x": extra, "T": 71.0])
        let result = try ReceiptResolver.resolve(data, foods: [sauce])
        #expect(abs(result.extras.reduce(0) { $0 + $1.price } - 69) < 0.001)
        #expect(result.extras.last?.label == ReceiptResolver.missingLabel)
    }

    @Test func aTotalThatIsExplainedAddsNothing() throws {
        let rows: [[String: Any]] = [["i": 0, "g": 650, "p": 2.0, "t": "A", "n": 1]]
        let data = try JSONSerialization.data(withJSONObject: ["m": rows, "x": [], "T": 2.2])
        #expect(try ReceiptResolver.resolve(data, foods: [sauce]).extras.isEmpty)
    }
}

@Suite struct ProductMemoryTests {
    private let sauce = Ingredient(name: "Sauce", emoji: "x", category: "Épicerie", kcal: 50, protein: 1, carbs: 8, fat: 1, packGrams: 400)

    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test func aLearnedProductFixesTheWeightTheAIGuessedWrong() throws {
        let memory = ProductMemory(label: ReceiptLabel.normalize("PANZANI SCE PROVENCALE"), ingredientID: sauce.id, unitGrams: 650, unitPrice: 2.1)
        let rows: [[String: Any]] = [["i": 0, "g": 800, "p": 4.2, "t": "PANZANI SCE PROVENCALE", "n": 2]]
        let data = try JSONSerialization.data(withJSONObject: ["m": rows, "x": []])
        #expect(try ReceiptResolver.resolve(data, foods: [sauce], memories: [memory]).matches.first?.grams == 1300)
        // Within 15 %: the printed weight is trusted.
        let close: [[String: Any]] = [["i": 0, "g": 1280, "p": 4.2, "t": "PANZANI SCE PROVENCALE", "n": 2]]
        let near = try JSONSerialization.data(withJSONObject: ["m": close, "x": []])
        #expect(try ReceiptResolver.resolve(near, foods: [sauce], memories: [memory]).matches.first?.grams == 1280)
    }

    @Test func aScanTeachesTheProductAndAHandTypedPackIsNotOverwritten() throws {
        let context = try context()
        context.insert(sauce)
        var match = ReceiptMatch(food: sauce, grams: 1300, price: 4.2, label: "PANZANI SCE PROVENCALE")
        match.units = 2
        ProductMemoryBook.learn([match], in: context)
        ProductMemoryBook.learnPack(from: match, in: context)
        #expect(sauce.packGrams == 650)
        let memory = try #require(try context.fetch(FetchDescriptor<ProductMemory>()).first { !$0.label.isEmpty })
        #expect(memory.unitGrams == 650 && abs(memory.unitPrice - 2.1) < 0.001)
        sauce.packGrams = 700
        ProductMemoryBook.lockPack(of: sauce, in: context)
        ProductMemoryBook.learnPack(from: match, in: context)
        #expect(sauce.packGrams == 700)
    }

    @Test func theTotalAfterDiscountsIsTheSpending() throws {
        let rows: [[String: Any]] = [["i": 0, "g": 650, "p": 5.0, "t": "A", "n": 1]]
        let data = try JSONSerialization.data(withJSONObject: ["m": rows, "x": [], "T": 4.0])
        let extra = try #require(try ResolverTotal.extras(data, sauce).first)
        #expect(extra.label == ReceiptResolver.discountLabel && abs(extra.price + 1) < 0.001)
    }
}

private enum ResolverTotal {
    static func extras(_ data: Data, _ food: Ingredient) throws -> [ReceiptExtra] { try ReceiptResolver.resolve(data, foods: [food]).extras }
}

@Suite struct SubstituteTests {
    @Test func sardinesAcceptMackerelOnTheReceiptAndTheList() {
        let sardines = Ingredient(name: "Sardines à l'huile", emoji: "x", category: "Conserves", kcal: 210, protein: 24, carbs: 0, fat: 12, pieceGrams: 80, pieceLabel: "boîte")
        #expect(FoodSubstitutes.title(sardines) == "Sardines à l'huile ou maquereau")
        #expect(ReceiptResolver.prompt(foods: [sardines], aliases: []).contains("|ou maquereau"))
        let rice = Ingredient(name: "Riz", emoji: "x", category: "Épicerie", kcal: 350, protein: 8, carbs: 77, fat: 1)
        #expect(FoodSubstitutes.title(rice) == "Riz")
    }
}

@Suite struct BatchTimersTests {
    @MainActor @Test func severalTimersRunAndSurviveARestart() throws {
        let defaults = try #require(UserDefaults(suiteName: "batch-timers-test"))
        defaults.removePersistentDomain(forName: "batch-timers-test")
        let timers = BatchTimers(defaults: defaults) {}
        timers.start(title: "Riz", seconds: 600)
        timers.start(title: "Pâtes", seconds: 300)
        #expect(timers.items.map(\.title) == ["Pâtes", "Riz"])
        timers.stop("Pâtes")
        #expect(timers.end(of: "Pâtes") == nil && timers.end(of: "Riz") != nil)
        // The app is closed and reopened: the running one is still there, one that ended meanwhile is gone.
        let reopened = BatchTimers(defaults: defaults) {}
        #expect(reopened.items.map(\.title) == ["Riz"])
        let later = BatchTimers(defaults: defaults, now: .now.addingTimeInterval(3600)) {}
        #expect(later.items.isEmpty)
        defaults.removePersistentDomain(forName: "batch-timers-test")
    }
}

@Suite struct SaturdayTicketTests {
    @Test func aSaturdayTicketClearsTheListOfTheWeekToCome() throws {
        var parts = DateComponents(year: 2026, month: 10, day: 31, hour: 13, minute: 40)
        parts.calendar = PlanCycle.calendar
        let saturday = try #require(parts.date)
        let steak = Ingredient(name: "Steak", emoji: "x", category: "Frais", kcal: 125, protein: 21, carbs: 0, fat: 5, stockGrams: 400)
        let meals = [PlanMeal(weekday: 2, slot: .lunch, items: [PlanItem(ingredientID: steak.id, grams: 500)])]
        let before = ShoppingList.cycleLines(meals: meals, ingredients: [steak], logs: [], checked: [], now: saturday)
        #expect(before.first?.toBuy == 100)
        let ticket = [PurchaseLog(ingredientID: steak.id, date: saturday.addingTimeInterval(-60), grams: 400, price: 8)]
        let after = ShoppingList.cycleLines(meals: meals, ingredients: [steak], logs: [], checked: [], purchases: ticket, now: saturday)
        #expect(after.first?.toBuy == 0)
        // A ticket from the week before the Friday evening does not count.
        let old = [PurchaseLog(ingredientID: steak.id, date: saturday.addingTimeInterval(-8 * 86_400), grams: 400, price: 8)]
        #expect(ShoppingList.cycleLines(meals: meals, ingredients: [steak], logs: [], checked: [], purchases: old, now: saturday).first?.toBuy == 100)
    }
}

@Suite struct SettleShoppingTests {
    @Test func tickedLinesNotOnTheTicketJoinTheStockAndLeaveTheList() {
        let rice = Ingredient(name: "Semoule", emoji: "x", category: "Épicerie", kcal: 350, protein: 8, carbs: 77, fat: 1, packGrams: 1000, stockGrams: 200)
        let oats = Ingredient(name: "Flocons", emoji: "x", category: "Épicerie", kcal: 370, protein: 13, carbs: 60, fat: 7, packGrams: 1000)
        let meals = [PlanMeal(weekday: 1, slot: .lunch, items: [PlanItem(ingredientID: rice.id, grams: 1000), PlanItem(ingredientID: oats.id, grams: 500)])]
        let lines = ShoppingList.lines(meals: meals, ingredients: [rice, oats], checked: [rice.id, oats.id])
        ShoppingList.settleChecked(lines, scanned: [oats.id])
        #expect(rice.stockGrams == 1000 && oats.stockGrams == 0)
        #expect(ShoppingList.lines(meals: meals, ingredients: [rice, oats], checked: []).first { $0.food.id == rice.id }?.toBuy == 0)
    }

    @Test func alreadyAtHomeCoversTheNeed() {
        let rice = Ingredient(name: "Semoule", emoji: "x", category: "Épicerie", kcal: 350, protein: 8, carbs: 77, fat: 1, packGrams: 1000, stockGrams: 300)
        let meals = [PlanMeal(weekday: 1, slot: .lunch, items: [PlanItem(ingredientID: rice.id, grams: 800)])]
        let line = ShoppingList.lines(meals: meals, ingredients: [rice], checked: [])[0]
        rice.stockGrams = ShoppingList.coveredStock(line)
        #expect(ShoppingList.lines(meals: meals, ingredients: [rice], checked: [])[0].toBuy == 0)
    }
}

@Suite struct ReceiptEditTests {
    private let eggs = Ingredient(name: "Œufs", emoji: "x", category: "Frais", kcal: 143, protein: 12, carbs: 1, fat: 9, pieceGrams: 60, pieceLabel: "œuf", packGrams: 720)
    private let banana = Ingredient(name: "Bananes", emoji: "x", category: "Fruits", kcal: 90, protein: 1, carbs: 20, fat: 0, pieceGrams: 100, pieceLabel: "banane")

    @Test func twoBoxesOfTwentyEggsReadAsSuch() {
        var match = ReceiptMatch(food: eggs, grams: 720, price: 9.78, label: "OEUF")
        #expect(match.soldInBoxes)
        match.set(units: 2, unitGrams: 20 * 60)
        #expect(match.grams == 2400 && match.quantityText == "2 × 20 œufs")
        #expect(!ReceiptMatch(food: banana, grams: 500, price: 1.69).soldInBoxes)
    }

    @Test func aBoxSizeIsLearnedFromTheTicket() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.insert(eggs)
        var match = ReceiptMatch(food: eggs, grams: 2400, price: 9.78, label: "OEUF")
        match.units = 2
        #expect(ProductMemoryBook.learnPack(from: match, in: context) && eggs.packGrams == 1200)
    }

    @Test func aFirstPurchaseNeverLooksUnusualButAHistoryDoes() {
        let match = ReceiptMatch(food: eggs, grams: 2400, price: 9.78)
        #expect(ReceiptGuard.warning(for: match, need: 2400, recent: [], now: .now) == nil)
        let past = (0..<2).map { _ in PurchaseLog(ingredientID: eggs.id, date: .now.addingTimeInterval(-7 * 86_400), grams: 1200, price: 1) }
        #expect(ReceiptGuard.warning(for: match, need: 2400, recent: past, now: .now) == .price)
    }

    @Test func anExplainedLineIsNamedOnTheNextTicket() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        var extra = ReceiptExtra(label: "GEL DCH 250", category: "Épicerie", price: 2, printed: "GEL DCH 250")
        extra.label = "Gel douche"; extra.category = "Maison"; extra.edited = true
        OffPlanBook.learn([extra], in: context)
        let known = try context.fetch(FetchDescriptor<OffPlanProduct>())
        let next = OffPlanBook.named([ReceiptExtra(label: "GEL DCH 250", category: "Épicerie", price: 2.1, printed: "GEL DCH 250")], with: known)
        #expect(next[0].label == "Gel douche" && next[0].category == "Maison")
    }
}

@Suite struct BoughtShoppingTests {
    @Test func aFoodTheTicketBroughtIsNotProposedAgain() {
        let steak = Ingredient(name: "Steak", emoji: "x", category: "Frais", kcal: 125, protein: 21, carbs: 0, fat: 5, stockGrams: 400)
        let meals = [PlanMeal(weekday: 1, slot: .lunch, items: [PlanItem(ingredientID: steak.id, grams: 500)])]
        #expect(ShoppingList.lines(meals: meals, ingredients: [steak], checked: []).first?.toBuy == 100)
        #expect(ShoppingList.lines(meals: meals, ingredients: [steak], checked: [], bought: [steak.id]).first?.toBuy == 0)
    }
}

@Suite struct ReceiptHistoryTests {
    @Test func linesAddedTogetherFormOneTicketAndNewestComesFirst() {
        let a = Ingredient(name: "A", emoji: "x", category: "Frais", kcal: 1, protein: 1, carbs: 1, fat: 1)
        let t0 = Date(timeIntervalSince1970: 1_000_000), t1 = t0.addingTimeInterval(86_400)
        let purchases = [PurchaseLog(ingredientID: a.id, date: t0, grams: 100, price: 2), PurchaseLog(ingredientID: a.id, date: t1, grams: 100, price: 3)]
        let extras = [ExtraPurchase(label: "x", category: "Autre", price: 4, date: t1.addingTimeInterval(5))]
        let tickets = ReceiptHistory.tickets(purchases: purchases, extras: extras)
        #expect(tickets.count == 2 && tickets[0].total == 7 && tickets[1].total == 2)
    }

    @Test func retypingALineMovesTheStockByTheDifference() {
        let a = Ingredient(name: "A", emoji: "x", category: "Frais", kcal: 1, protein: 1, carbs: 1, fat: 1, stockGrams: 500)
        let log = PurchaseLog(ingredientID: a.id, grams: 500, price: 2)
        ReceiptHistory.correct(log, grams: 400, price: 2.5, food: a)
        #expect(a.stockGrams == 400 && log.grams == 400 && log.price == 2.5)
        ReceiptHistory.removeStock(of: log, food: a)
        #expect(a.stockGrams == 0)
    }
}

@Suite struct CarryListTests {
    private func named(_ name: String, category: String = "Épicerie", piece: Double = 0, label: String = "") -> Ingredient {
        Ingredient(name: name, emoji: "x", category: category, kcal: 100, protein: 10, carbs: 0, fat: 0, pieceGrams: piece, pieceLabel: label)
    }
    let egg = Ingredient(name: "Œufs", emoji: "x", category: "Frais", kcal: 143, protein: 12, carbs: 0, fat: 9, pieceGrams: 60, pieceLabel: "œuf")
    let cheese = Ingredient(name: "Fromage blanc 0 %", emoji: "x", category: "Frais", kcal: 50, protein: 8, carbs: 4, fat: 0)
    let steak = Ingredient(name: "Steak haché 5 %", emoji: "x", category: "Frais", kcal: 130, protein: 21, carbs: 0, fat: 5)
    let oil = Ingredient(name: "Huile d'olive", emoji: "x", category: "Épicerie", kcal: 900, protein: 0, carbs: 0, fat: 100)
    let bread = Ingredient(name: "Pain complet", emoji: "x", category: "Boulangerie", kcal: 250, protein: 9, carbs: 45, fat: 2)
    let steps = [BatchStep(order: 0, title: "Steaks", detail: ""), BatchStep(order: 1, title: "Refroidissement", detail: "")]

    private var week: [PlanMeal] {
        (1...7).flatMap { day in
            [PlanMeal(weekday: day, slot: .breakfast, items: [PlanItem(ingredientID: egg.id, grams: 240), PlanItem(ingredientID: bread.id, grams: 75)]),
             PlanMeal(weekday: day, slot: .lunch, items: [PlanItem(ingredientID: steak.id, grams: 100), PlanItem(ingredientID: oil.id, grams: 10)]),
             PlanMeal(weekday: day, slot: .snack, items: [PlanItem(ingredientID: cheese.id, grams: 250)]),
             PlanMeal(weekday: day, slot: .dinner, items: [PlanItem(ingredientID: egg.id, grams: 240)]),
             PlanMeal(weekday: day, slot: .evening, items: [PlanItem(ingredientID: cheese.id, grams: 200)])]
        }
    }
    private var lines: [CarryList.Line] { CarryList.lines(meals: week, ingredients: [egg, cheese, steak, oil, bread], steps: steps) }

    @Test func coversSundayAfterDinnerToFridaySnack() {
        // Eggs: Mon–Thu breakfast + dinner (8 × 4) + Friday breakfast (4); Sunday's dinner and Friday's dinner are at home.
        #expect(lines.first { $0.food.id == egg.id }?.text == "36 œufs")
        // Cheese: Sunday evening + Mon–Thu (snack + evening) + Friday snack.
        #expect(lines.first { $0.food.id == cheese.id }?.grams == 2250)
        #expect(lines.first { $0.food.id == bread.id }?.text == "5 bouts")
    }

    @Test func batchFoodStaysOffAndAStapleIsCarriedOnlyForWhatTheFlatLacks() {
        #expect(!lines.contains { $0.food.id == steak.id })
        // Oil: 10 g × 5 lunches at the flat. Never brought when the flat holds enough, else only the missing part.
        #expect(lines.first { $0.food.id == oil.id }?.grams == 50)
        func carried(flat: Double) -> Double? {
            CarryList.lines(meals: week, ingredients: [oil], steps: steps, flat: [oil.id: flat]).first?.grams
        }
        #expect(carried(flat: 50) == nil && carried(flat: 80) == nil)
        #expect(carried(flat: 30) == 20)
    }
}

@Suite struct FlatStockTests {
    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }
    private let tuna = Ingredient(name: "Thon naturel", emoji: "x", category: "Conserves", kcal: 110, protein: 25, carbs: 0, fat: 1, pieceGrams: 113, pieceLabel: "boîte", packGrams: 339, stockGrams: 1000)

    @Test func tunaIsCarriedInWholeCans() {
        #expect(FlatStockBook.deficit(need: 226, atFlat: 0, food: tuna) == 226)
        #expect(FlatStockBook.deficit(need: 226, atFlat: 120, food: tuna) == 113)
        #expect(FlatStockBook.deficit(need: 226, atFlat: 300, food: tuna) == 0)
    }

    @Test func eatingAtTheFlatUsesItsPartButEatingAtHomeDoesNot() throws {
        let context = try context()
        context.insert(tuna)
        context.insert(FlatStock(ingredientID: tuna.id, grams: 339))
        let monday = PlanMeal(weekday: 2, slot: .lunch, items: [PlanItem(ingredientID: tuna.id, grams: 113)])
        let saturday = PlanMeal(weekday: 7, slot: .lunch, items: [PlanItem(ingredientID: tuna.id, grams: 113)])
        FlatStockBook.shift(saturday, sign: -1, foods: [tuna.id: tuna], in: context)
        #expect(try context.fetch(FetchDescriptor<FlatStock>()).first?.grams == 339)
        FlatStockBook.shift(monday, sign: -1, foods: [tuna.id: tuna], in: context)
        #expect(try context.fetch(FetchDescriptor<FlatStock>()).first?.grams == 226)
        FlatStockBook.shift(monday, sign: 1, foods: [tuna.id: tuna], in: context)
        #expect(try context.fetch(FetchDescriptor<FlatStock>()).first?.grams == 339)
    }

    @Test func theFlatNeverHoldsMoreThanTheStock() {
        let row = FlatStock(ingredientID: tuna.id, grams: 5000)
        #expect(FlatStockBook.grams([row], foods: [tuna])[tuna.id] == 1000)
    }
}

@Suite struct BatchWindowTests {
    private func at(_ day: Int, _ hour: Int, month: Int = 10) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: 13))!
    }

    // Bug of 30 Oct: « Fait, suivante » on Friday evening did nothing, the window only opened on Sunday.
    @Test func aStepTickedFridayEveningCountsAtOnceAndOnSunday() {
        let step = BatchStep(order: 0, title: "Riz", detail: "", completedAt: at(30, 19))
        #expect(step.isDone(now: at(30, 19)))
        #expect(step.isDone(now: at(1, 10, month: 11)))
    }

    @Test func lastWeeksBatchDoesNotCountForTheNextOne() {
        let step = BatchStep(order: 0, title: "Riz", detail: "", completedAt: at(25, 11))
        #expect(!step.isDone(now: at(30, 19)))
        #expect(step.isDone(now: at(30, 17)))
    }
}

@Suite struct ExerciseLibraryTests {
    @Test func offersTheOtherProgramsExercisesOnce() {
        let mine = Exercise(name: "Pec deck", muscleGroup: "Pectoraux")
        let library = [ExerciseLibrary.Entry(name: "Pec deck", muscleGroup: "Pectoraux", unilateral: false),
                       ExerciseLibrary.Entry(name: "Hip thrust machine", muscleGroup: "Fessiers", unilateral: false)]
        let rows = ExerciseLibrary.choices(stored: [mine], library: library)
        #expect(rows.map(\.name) == ["Hip thrust machine", "Pec deck"])
        #expect(rows.last?.exercise === mine && rows.first?.exercise == nil)
    }
}

@Suite struct PackToleranceTests {
    private func packs(need: Double, pack: Double) -> Int {
        let food = Ingredient(name: "Fromage blanc", emoji: "x", category: "Frais", kcal: 50, protein: 8, carbs: 4, fat: 0, packGrams: pack)
        let meal = PlanMeal(weekday: 2, slot: .lunch, items: [PlanItem(ingredientID: food.id, grams: need)])
        return ShoppingList.lines(meals: [meal], ingredients: [food], checked: []).first?.packs ?? -1
    }

    @Test func tenGramsOverOnePackDoesNotBuyAnotherOne() {
        #expect(packs(need: 3850, pack: 960) == 4, "4 pots = 3,84 kg for 3,85 kg: no 5th pot for 10 g")
        #expect(packs(need: 3900, pack: 960) == 5, "a real shortfall still buys the next pack")
        #expect(packs(need: 960, pack: 960) == 1)
        #expect(packs(need: 50, pack: 960) == 1, "a small need still buys one pack")
    }
}

@Suite struct LiveRecordTests {
    typealias Prior = LiveRecord.Prior
    private let history = [Prior(weight: 60, reps: 10), Prior(weight: 70, reps: 6), Prior(weight: 60, reps: 8)]

    @Test func heavierThanEverIsAWeightRecord() {
        #expect(LiveRecord.kind(weight: 72.5, reps: 3, prior: history) == .weight)
        #expect(LiveRecord.kind(weight: 70, reps: 6, prior: history) == nil)
    }

    @Test func moreRepsThanEverAtThatWeightOrMoreIsARepRecord() {
        #expect(LiveRecord.kind(weight: 70, reps: 7, prior: history) == .reps)
        #expect(LiveRecord.kind(weight: 60, reps: 11, prior: history) == .reps)
        // 60 × 7 is beaten by 70 × 6 (heavier AND more reps than... 6 < 7): 60 × 7 is not a record against 60 × 10.
        #expect(LiveRecord.kind(weight: 60, reps: 7, prior: history) == nil)
        #expect(LiveRecord.kind(weight: 50, reps: 10, prior: history) == nil)
    }

    @Test func noMedalTheFirstTimeAndOnlyTheFirstSetThatReachesTheBest() {
        #expect(LiveRecord.medals(done: [(0, 60, 10)], history: []).isEmpty)
        let medals = LiveRecord.medals(done: [(0, 72.5, 3), (1, 72.5, 3), (2, 72.5, 4)], history: history)
        #expect(medals == [0: .weight, 2: .reps])
    }
}

@Suite struct SpendingStatsTests {
    private let cheese = Ingredient(name: "Fromage blanc", emoji: "x", category: "Frais", kcal: 46, protein: 8, carbs: 4, fat: 0)

    @Test func weeksAreSplitIntoPlanAndOthersAndTheAverageIgnoresTheRunningWeek() {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        let thisWeek = WeekReview.weekStart(containing: now)
        let lastWeek = WeekReview.weekStart(containing: now, offset: -1).addingTimeInterval(3600)
        let stats = SpendingStats(
            purchases: [PurchaseLog(ingredientID: cheese.id, date: lastWeek, grams: 960, price: 50), PurchaseLog(ingredientID: cheese.id, date: thisWeek.addingTimeInterval(3600), grams: 960, price: 20)],
            extras: [ExtraPurchase(label: "x", category: "Autre", price: 10, date: lastWeek)], foods: [cheese], now: now)
        #expect(stats.weeks.count == SpendingStats.weekCount && stats.weeks.last?.plan == 20)
        #expect(stats.weeks[SpendingStats.weekCount - 2].extra == 10 && stats.weeklyAverage == 60)
        #expect(stats.dailyAverage.map { abs($0 - 60.0 / 7) < 0.001 } == true)
    }

    @Test func aPriceThatMovedByTenPercentIsListedAndNoiseIsNot() {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        func buy(_ daysAgo: Double, _ price: Double) -> PurchaseLog { PurchaseLog(ingredientID: cheese.id, date: now.addingTimeInterval(-daysAgo * 86_400), grams: 1000, price: price) }
        let up = SpendingStats(purchases: [buy(30, 2), buy(20, 2), buy(1, 2.6)], extras: [], foods: [cheese], now: now)
        #expect(up.movers.first.map { abs($0.change - 0.3) < 0.001 } == true)
        let flat = SpendingStats(purchases: [buy(30, 2), buy(20, 2), buy(1, 2.1)], extras: [], foods: [cheese], now: now)
        #expect(flat.movers.isEmpty)
        let few = SpendingStats(purchases: [buy(20, 2), buy(1, 3)], extras: [], foods: [cheese], now: now)
        #expect(few.movers.isEmpty)
    }
}

@Suite struct SpendingBreakdownTests {
    /// Pasta, oats, bread and rice hold 8–13 g of protein but are carbs: they must not top « 100 g de protéines » (found 31 Oct).
    @Test func starchesAreNotProteinSources() {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        let pasta = Ingredient(name: "Pâtes", emoji: "x", category: "Épicerie", kcal: 350, protein: 13, carbs: 66, fat: 2.5, packGrams: 500, packPrice: 1)
        let oats = Ingredient(name: "Flocons", emoji: "x", category: "Épicerie", kcal: 370, protein: 13, carbs: 60, fat: 7, packGrams: 1000, packPrice: 1.5)
        let chicken = Ingredient(name: "Poulet", emoji: "x", category: "Boucherie", kcal: 120, protein: 23, carbs: 0, fat: 2, packGrams: 1000, packPrice: 9)
        let stats = SpendingStats(purchases: [], extras: [], foods: [pasta, oats, chicken], now: now)
        #expect(stats.proteinCosts.map(\.name) == ["Poulet"])
    }

    @Test func theMoneyIsSplitByCategoryAndProteinCostsComeFromThePantry() {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        let eggs = Ingredient(name: "Œufs", emoji: "x", category: "Frais", kcal: 143, protein: 12.5, carbs: 1, fat: 9, packGrams: 1200, packPrice: 5)
        let oil = Ingredient(name: "Huile", emoji: "x", category: "Épicerie", kcal: 884, protein: 0, carbs: 0, fat: 100, packGrams: 920, packPrice: 6)
        let day = WeekReview.weekStart(containing: now).addingTimeInterval(60)
        let stats = SpendingStats(
            purchases: [PurchaseLog(ingredientID: eggs.id, date: day, grams: 1200, price: 5), PurchaseLog(ingredientID: oil.id, date: day, grams: 920, price: 6)],
            extras: [ExtraPurchase(label: "Eau", category: "Boisson", price: 2, date: day)], foods: [eggs, oil], now: now)
        #expect(stats.shares.map(\.name) == ["Épicerie", "Frais", "Boisson"] && stats.tickets == 1)
        // 5 € / 1 200 g = 0.4167 € per 10 g... per 100 g of eggs: 0.4167; 12.5 g protein per 100 g → 3.33 € per 100 g of protein.
        #expect(stats.proteinCosts.count == 1 && abs((stats.proteinCosts.first?.euros ?? 0) - 3.333) < 0.01)
    }
}

@Suite struct StockTextTests {
    @Test func stockIsShownInTheUnitItIsBoughtIn() {
        let tuna = Ingredient(name: "Thon", emoji: "x", category: "Conserves", kcal: 1, protein: 1, carbs: 0, fat: 0, pieceGrams: 113, pieceLabel: "boîte", packGrams: 339, stockGrams: 339)
        let sauce = Ingredient(name: "Sauce", emoji: "x", category: "Épicerie", kcal: 1, protein: 1, carbs: 0, fat: 0, packGrams: 650, stockGrams: 1950)
        let oil = Ingredient(name: "Huile", emoji: "x", category: "Épicerie", kcal: 1, protein: 0, carbs: 0, fat: 100, packGrams: 920, stockGrams: 125)
        #expect(QuantityFormatter.stock(tuna) == "3 boîtes")
        #expect(QuantityFormatter.stock(sauce) == "3 × 650 g")
        #expect(QuantityFormatter.stock(oil) == "125 g")
        sauce.stockGrams = 1700
        #expect(QuantityFormatter.stock(sauce) == "1,7 kg")
    }
}
