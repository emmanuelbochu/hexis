import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// Two years of life (4 sessions a week, 3 meals a day) and a time budget per heavy computation: an O(n²) calculation that
/// would freeze the iPhone fails here instead. Each budget is about 2× the time measured while check.sh also compiles (2026-10-29, debug build).
@Suite(.serialized) struct PerformanceTests {
    @MainActor private static func twoYears() throws -> (ModelContext, now: Date) {
        ProgramCatalog.fileURL = LifeSimulator.appProgramFile
        for key in ["programFileHash", "programStructureHash", ProgramSync.startKey] { UserDefaults.standard.removeObject(forKey: key) }
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        ProgramSync.sync(in: context)
        let calendar = WeekReview.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)) ?? .now
        let templates = (try context.fetch(FetchDescriptor<Program>())).first?.templates.sorted { $0.order < $1.order } ?? []
        let gym = Gym(name: "Salle")
        context.insert(gym)
        var rng = SystemRandomNumberGenerator()
        for week in 0..<104 {
            for slot in 0..<4 {
                let day = calendar.date(byAdding: .day, value: -(103 - week) * 7 - 6 + slot * 2, to: now) ?? now
                let template = templates[slot % templates.count]
                let session = WorkoutSession(date: day, gymID: gym.id, templateID: template.id)
                session.endedAt = day.addingTimeInterval(3_600)
                session.state = .finished
                context.insert(session)
                var index = 0
                for block in template.blocks {
                    for exercise in block.exercises {
                        for set in 0..<3 {
                            index += 1
                            context.insert(SetLog(
                                sessionID: session.id, exerciseID: exercise.exerciseID, gymID: gym.id, index: index,
                                weight: 20 + Double(week) * 0.25 + Double.random(in: 0...2, using: &rng).rounded(),
                                reps: 8 + set % 3, rir: 2, completedAt: day.addingTimeInterval(Double(index) * 150)
                            ))
                        }
                    }
                }
            }
        }
        for day in 0..<730 {
            let date = calendar.date(byAdding: .day, value: -day - 1, to: now) ?? now
            for slot in [MealSlot.breakfast, .lunch, .dinner] {
                context.insert(FoodEntry(date: date, meal: slot, name: "x", kcal: 700, protein: 40, carbs: 80, fat: 20))
            }
        }
        try context.save()
        return (context, now)
    }

    /// Runs `body` and fails when it takes longer than `budget` seconds.
    private func within(_ budget: Double, _ name: String, _ body: () throws -> Void) rethrows {
        let start = ContinuousClock.now
        try body()
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        print("perf · \(name) : \(String(format: "%.3f", seconds)) s (budget \(budget) s)")
        #expect(seconds < budget, "\(name) took \(seconds) s, budget \(budget) s")
    }

    @Test @MainActor func heavyCalculationsStayWithinBudget() throws {
        let (context, now) = try Self.twoYears()
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let sets = try context.fetch(FetchDescriptor<SetLog>())
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let template = try #require(try context.fetch(FetchDescriptor<Program>()).first?.templates.first)
        let gymID = sessions.first?.gymID

        within(BUDGET_WEEK_REVIEW, "WeekReview, 8 semaines") {
            for offset in 0..<8 {
                _ = WeekReview(start: WeekReview.weekStart(containing: now, offset: -offset), sessions: sessions, sets: sets, exercises: byID)
            }
        }
        var intake: [Date: Macros] = [:]
        within(BUDGET_INTAKE, "DailyIntake, 2 ans") { intake = DailyIntake.load(in: context, since: now.addingTimeInterval(-730 * 86_400), now: now) }
        within(BUDGET_INSIGHTS, "Insights") {
            let points = Insights.points(sessions: sessions, sets: sets, loads: LoadResolver(loads: [], exercises: exercises), intake: intake)
            _ = Insights.ranked(Insights.insights(from: points))
        }
        within(BUDGET_STAGNATION, "StagnationDetector, tous les exos") { _ = StagnationDetector.findings(sets: sets, feelings: [], now: now) }
        within(BUDGET_ADJUSTER, "SessionAdjuster, une séance") {
            _ = SessionAdjuster.load(template: template, gymID: gymID, context: context, now: now)
        }
        let ingredients = (0..<60).map { Ingredient(name: "Aliment \($0)", emoji: "x", category: "Épicerie", kcal: 100, protein: 5, carbs: 10, fat: 2, stockGrams: 300) }
        let meals = (1...7).flatMap { weekday in
            [MealSlot.breakfast, .lunch, .dinner].map { PlanMeal(weekday: weekday, slot: $0, items: ingredients.prefix(8).map { PlanItem(ingredientID: $0.id, grams: 120) }) }
        }
        within(BUDGET_SHOPPING, "ShoppingList") { _ = ShoppingList.lines(meals: meals, ingredients: ingredients, checked: []) }
    }
}

private let BUDGET_WEEK_REVIEW = 2.0
private let BUDGET_INTAKE = 0.25
private let BUDGET_INSIGHTS = 0.7
private let BUDGET_STAGNATION = 2.4
private let BUDGET_ADJUSTER = 1.7
private let BUDGET_SHOPPING = 0.1
