import SwiftData
import SwiftUI

struct NutritionPlanView: View {
    @Query private var meals: [PlanMeal]
    @Query private var ingredients: [Ingredient]
    @Query private var batchSteps: [BatchStep]
    @State private var weekday = Calendar.current.component(.weekday, from: .now)

    private static let days: [(weekday: Int, label: String)] = [(2, "L"), (3, "M"), (4, "M"), (5, "J"), (6, "V"), (7, "S"), (1, "D")]

    private var foodByID: [UUID: Ingredient] { PlanCalculator.lookup(ingredients) }
    private var dayMeals: [PlanMeal] { meals.filter { $0.weekday == weekday }.sorted { $0.slot.order < $1.slot.order } }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                if !batchSteps.isEmpty { BatchLinkCard(steps: batchSteps) }
                dayPicker
                let total = PlanCalculator.macros(of: dayMeals, ingredients: foodByID)
                Text("\(total.kcal) kcal · \(Int(total.protein)) g prot. · \(Int(total.carbs)) g gluc. · \(Int(total.fat)) g lip.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                ForEach(dayMeals) { meal in
                    PlanMealCard(meal: meal, ingredients: foodByID)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .onAppear { UsageCounter.hit(.nutritionPlan) }
    }

    private var dayPicker: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Self.days, id: \.weekday) { day in
                Button { weekday = day.weekday } label: {
                    Text(day.label)
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(weekday == day.weekday ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
                        .background(weekday == day.weekday ? Theme.Colors.accent : Theme.Colors.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: weekday)
    }
}

#Preview {
    NutritionPlanView()
        .modelContainer(for: PlanMeal.self, inMemory: true)
        .appAppearance()
}
