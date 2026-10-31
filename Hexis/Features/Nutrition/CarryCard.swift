import SwiftUI

/// Sunday's « À emmener à l'appart »: the week's foods that do not go in the boxes, just to read while packing the bag.
struct CarryCard: View {
    let lines: [CarryList.Line]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("À emmener à l'appart", systemImage: "bag.fill")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Dimanche soir → vendredi collation, hors boîtes du batch")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            ForEach(lines) { line in
                HStack(spacing: Theme.Spacing.m) {
                    Text("\(line.food.emoji) \(line.food.name)")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(line.text)
                        .font(Theme.Fonts.headline.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .frame(minHeight: 40)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    let egg = Ingredient(name: "Œufs", emoji: "🥚", category: "Frais", kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, pieceGrams: 60, pieceLabel: "œuf")
    CarryCard(lines: [CarryList.Line(food: egg, grams: 1200, portions: 5)])
        .padding()
        .appAppearance()
}
