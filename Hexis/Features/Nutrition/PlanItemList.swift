import SwiftUI

/// The foods of a planned meal, one line each: "🥚 4 œufs".
struct PlanItemList: View {
    let items: [PlanItem]
    let ingredients: [UUID: Ingredient]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if let food = ingredients[item.ingredientID] {
                    HStack {
                        Text("\(food.emoji) \(food.name)")
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(QuantityFormatter.text(grams: item.grams, of: food))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .monospacedDigit()
                    }
                    .font(Theme.Fonts.body)
                }
            }
        }
    }
}
