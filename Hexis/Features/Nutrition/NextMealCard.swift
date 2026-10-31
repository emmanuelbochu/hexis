import SwiftUI

/// The meal to eat now: what to put on the plate, one tap to validate.
struct NextMealCard: View {
    let meal: PlanMeal
    let ingredients: [UUID: Ingredient]
    let onEat: () -> Void

    var body: some View {
        let macros = PlanCalculator.macros(of: meal.items, ingredients: ingredients)
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Label(meal.slot.label, systemImage: meal.slot.systemImage)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.accent)
                Spacer()
                Text("\(macros.kcal) kcal · \(Int(macros.protein)) g de protéines")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            PlanItemList(items: meal.items, ingredients: ingredients)
            Button(action: onEat) { Label("Mangé", systemImage: "checkmark") }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Spacing.m)
        .cardStyle()
        .sensoryFeedback(.success, trigger: meal.id)
    }
}
