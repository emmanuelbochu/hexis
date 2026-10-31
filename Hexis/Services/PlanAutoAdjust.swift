import Foundation
import SwiftData

/// Moves the weekly plan by itself toward the phase: when the scale (6 weigh-ins over 14 days since the last change) says
/// the bulk is too slow or too fast, the starchy foods (rice, pasta, oats) are scaled by up to 150 kcal a day, at
/// most every 14 days and within ±400 kcal in all. Shopping, stock and the daily goal follow because they read the plan,
/// the batch recipe through `BatchScaling`. Changes are made on Saturday or Sunday only: shopping and batch cooking then
/// start from the new plan and a week is never half one quantity, half another.
enum PlanAutoAdjust {
    static let totalKey = "planKcalDelta"
    static let dateKey = "planAdjustedOn"
    static let noteKey = "planAdjustNote"
    /// Cumulative factor on the plan's starchy quantities since the seed (the batch recipe follows it).
    static let scaleKey = "planStarchScale"
    static let verdictKey = "bodyPhaseVerdict"
    static let verdictDateKey = "bodyPhaseVerdictOn"
    private static let checkedKey = "planCheckedOn"
    private static let maxTotal = 400
    private static let minWeighIns = 6
    private static let verdictDays = 21

    /// A starchy food: dry carbohydrate source, where grams move the calories without touching the protein.
    private static func isStarch(_ food: Ingredient) -> Bool { food.carbs >= 45 && food.kcal >= 300 }

    /// True while the last verdict of the scale is « too slow » (recent): a plateau is then fed before being trained around.
    static func isUnderfed(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.string(forKey: verdictKey) == "tooSlow", let on = defaults.object(forKey: verdictDateKey) as? Date else { return false }
        return now.timeIntervalSince(on) <= Double(verdictDays) * 86_400
    }

    /// Once a day: reads the scale and the food, remembers the verdict and, when it is off, moves the plan.
    @MainActor private static var isRunning = false

    @MainActor static func runIfDue(in context: ModelContext, now: Date = .now, defaults: UserDefaults = .standard) async {
        // Launch and foreground both call it: the second call must not run on stale data while the first awaits the scale.
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        let calendar = Calendar.current
        if let last = defaults.object(forKey: checkedKey) as? Date, calendar.isDate(last, inSameDayAs: now) { return }
        // Holidays and the week after: the scale follows meals the plan knows nothing about.
        guard !FreePeriod.pausesAdjustment(in: context, now: now) else { return }
        let adjustedOn = defaults.object(forKey: dateKey) as? Date
        let since = max(adjustedOn ?? .distantPast, calendar.date(byAdding: .day, value: -35, to: now) ?? now)
        let weights = await HealthService.weights(since: since)
        guard !weights.isEmpty else { return }
        defaults.set(now, forKey: checkedKey)
        let intake = DailyIntake.load(in: context, since: since, now: now)
        let range = NutritionGoals.proteinRange(weightKg: weights.last?.value)
        guard let slope = BodyInsights.slope(weights: weights, intake: intake, now: now),
              let check = PhaseCheck.make(goal: NutritionGoals.phase, slope: slope, proteinRange: range) else { return }
        // « Too slow » only holds sessions back while the plan can still feed (food followed, cap not reached).
        let canFeed = slope.kcalPerDay != nil && defaults.integer(forKey: totalKey) < maxTotal
        defaults.set(check.verdict == .tooSlow && !canFeed ? "stuck" : verdictName(check.verdict), forKey: verdictKey)
        defaults.set(now, forKey: verdictDateKey)
        // A plan not followed (food rarely logged) or a noisy scale must not move the plan.
        guard check.verdict != .onTrack, slope.weighIns >= minWeighIns, slope.kcalPerDay != nil,
              [7, 1].contains(calendar.component(.weekday, from: now)) else { return }
        let total = defaults.integer(forKey: totalKey)
        let step = min(max(total + check.kcalDelta, -maxTotal), maxTotal) - total
        guard step != 0 else { return }
        let meals = (try? context.fetch(FetchDescriptor<PlanMeal>())) ?? []
        let foods = PlanCalculator.lookup((try? context.fetch(FetchDescriptor<Ingredient>())) ?? [])
        let before = dailyKcal(meals, foods), starchBefore = starchGrams(meals, foods)
        guard starchBefore > 0 else { return }
        apply(kcalPerDay: step, to: meals, foods: foods)
        let moved = dailyKcal(meals, foods) - before
        let scale = defaults.object(forKey: scaleKey) as? Double ?? 1
        defaults.set(scale * starchGrams(meals, foods) / starchBefore, forKey: scaleKey)
        defaults.set(total + moved, forKey: totalKey)
        guard moved != 0 else { context.saveReportingFailure(); return }
        defaults.set(now, forKey: dateKey)
        defaults.set("\(now.formatted(.dateTime.day().month(.abbreviated))) : plan \(moved > 0 ? "+" : "−")\(abs(moved)) kcal/j (féculents des repas et de la collation).", forKey: noteKey)
        context.saveReportingFailure()
    }

    /// Scales the starchy foods of each weekday so that its calories move by about `kcalPerDay` (grams to the nearest 5).
    static func apply(kcalPerDay: Int, to meals: [PlanMeal], foods: [UUID: Ingredient]) {
        for dayMeals in Dictionary(grouping: meals, by: \.weekday).values {
            let starchKcal = dayMeals.flatMap(\.items).reduce(0.0) { sum, item in
                guard let food = foods[item.ingredientID], isStarch(food) else { return sum }
                return sum + item.grams / 100 * food.kcal
            }
            guard starchKcal > 0 else { continue }
            let factor = min(max(1 + Double(kcalPerDay) / starchKcal, 0.7), 1.4)
            for meal in dayMeals {
                meal.items = meal.items.map { item in
                    guard let food = foods[item.ingredientID], isStarch(food) else { return item }
                    return PlanItem(ingredientID: item.ingredientID, grams: max((item.grams * factor / 5).rounded() * 5, 5))
                }
            }
        }
    }

    private static func starchGrams(_ meals: [PlanMeal], _ foods: [UUID: Ingredient]) -> Double {
        meals.flatMap(\.items).reduce(0) { sum, item in
            guard let food = foods[item.ingredientID], isStarch(food) else { return sum }
            return sum + item.grams
        }
    }

    /// Mean calories per day of the plan.
    static func dailyKcal(_ meals: [PlanMeal], _ foods: [UUID: Ingredient]) -> Int {
        let days = Set(meals.map(\.weekday)).count
        return days > 0 ? PlanCalculator.macros(of: meals, ingredients: foods).kcal / days : 0
    }

    private static func verdictName(_ verdict: PhaseCheck.Verdict) -> String {
        switch verdict {
        case .onTrack: "onTrack"
        case .tooSlow: "tooSlow"
        case .tooFast: "tooFast"
        }
    }
}
