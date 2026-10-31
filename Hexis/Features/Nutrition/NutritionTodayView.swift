import SwiftData
import SwiftUI

struct NutritionTodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var flatStocks: [FlatStock]
    @Query private var meals: [PlanMeal]
    @Query private var logs: [PlanMealLog]
    @Query private var ingredients: [Ingredient]
    @Query private var batchSteps: [BatchStep]
    /// The meal just validated, kept a few seconds so a wrong tap can be taken back.
    @State private var justEaten: (id: UUID, name: String)?
    @AppStorage(PlanAutoAdjust.noteKey) private var planNote = ""
    @State private var pause: FreePeriod.Status?

    private var foodByID: [UUID: Ingredient] { PlanCalculator.lookup(ingredients) }
    /// Read again when the app comes back: a screen left open overnight shows the new day.
    @State private var now = Date.now
    @Environment(\.scenePhase) private var scenePhase
    private var weekday: Int { Calendar.current.component(.weekday, from: now) }
    private var batchPending: Bool { weekday == 1 && !batchSteps.isEmpty && batchSteps.contains { !$0.isDone() } }
    /// Sunday (and not before a holiday week, spent at home): what to bring to the flat, ready before and after the batch.
    private var carryLines: [CarryList.Line] {
        guard weekday == 1, Calendar.current.component(.hour, from: now) < CarryList.hiddenFromHour, !FreePeriod.isHolidayCycle(PlanCycle.start(for: now)) else { return [] }
        return CarryList.lines(meals: meals, ingredients: ingredients, steps: batchSteps, flat: FlatStockBook.grams(flatStocks, foods: ingredients))
    }

    private var nextMeal: PlanMeal? {
        let done = Set(logs.filter { Calendar.current.isDateInToday($0.day) }.map(\.planMealID))
        return NextMealPicker.pick(meals: meals, doneIDs: done, weekday: Calendar.current.component(.weekday, from: .now), hour: Calendar.current.component(.hour, from: .now))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                if batchPending { BatchLinkCard(steps: batchSteps) }
                let carry = carryLines
                if !carry.isEmpty { CarryCard(lines: carry) }
                if let meal = nextMeal {
                    NextMealCard(meal: meal, ingredients: foodByID) {
                        if let entry = MealLogger.eat(meal, ingredients: foodByID, in: context) {
                            justEaten = (entry.id, entry.name)
                            SoundService.play(.mealDone)
                        }
                    }
                } else if !meals.isEmpty {
                    Label("Journée terminée", systemImage: "checkmark.seal.fill")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
                        .cardStyle()
                }
                if let eaten = justEaten {
                    Button {
                        MealLogger.undo(entryID: eaten.id, ingredients: foodByID, in: context)
                        justEaten = nil
                    } label: {
                        Label("Annuler : \(eaten.name)", systemImage: "arrow.uturn.backward")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
                    }
                    .task(id: eaten.id) {
                        try? await Task.sleep(for: .seconds(10))
                        if !Task.isCancelled { justEaten = nil }
                    }
                }
                WeightCard()
                if let pause {
                    Label(pause.text, systemImage: "beach.umbrella.fill")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                if !planNote.isEmpty {
                    Text(planNote).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .task(id: Calendar.current.startOfDay(for: now)) { pause = FreePeriod.status(in: context, now: now) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
    }
}

#Preview {
    NutritionTodayView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
        .appAppearance()
}
