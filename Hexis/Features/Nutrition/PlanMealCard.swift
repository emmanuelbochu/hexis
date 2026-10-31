import SwiftUI

struct PlanMealCard: View {
    let meal: PlanMeal
    let ingredients: [UUID: Ingredient]

    var body: some View {
        let macros = PlanCalculator.macros(of: meal.items, ingredients: ingredients)
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Label(meal.slot.label, systemImage: meal.slot.systemImage)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(macros.kcal) kcal · \(Int(macros.protein)) g de protéines")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            PlanItemList(items: meal.items, ingredients: ingredients)
        }
        .padding(Theme.Spacing.m)
        .cardStyle()
    }
}
