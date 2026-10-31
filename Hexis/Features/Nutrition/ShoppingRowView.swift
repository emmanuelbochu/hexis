import SwiftUI

struct ShoppingRowView: View {
    let line: ShoppingLine
    let onToggle: () -> Void

    /// What is already at home has nothing to tick.
    private var ticks: Bool { line.toBuy > 0 }

    var body: some View {
        if ticks {
            Button(action: onToggle) { row }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: line.checked)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: Theme.Spacing.m) {
            if ticks {
                Image(systemName: line.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(line.checked ? Theme.Colors.accent : Theme.Colors.textSecondary)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(line.food.emoji) \(FoodSubstitutes.title(line.food))")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(line.checked ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    .strikethrough(line.checked)
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            if line.toBuy > 0 {
                Text(line.buyText)
                    .font(Theme.Fonts.headline.monospacedDigit())
                    .foregroundStyle(line.checked ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(minHeight: Theme.Layout.minTapHeight)
        .cardStyle()
    }

    private var subtitle: String {
        guard line.toBuy > 0 else { return "Stock : \(QuantityFormatter.stock(line.food))" }
        var parts: [String] = []
        if !line.isBakery, line.packs > 0 { parts.append(QuantityFormatter.text(grams: line.toBuy, of: line.food)) }
        if line.cost > 0 { parts.append(QuantityFormatter.price(line.cost)) }
        if line.food.stockGrams > 0 { parts.append("déjà \(QuantityFormatter.stock(line.food))") }
        return parts.isEmpty ? "Semaine : \(QuantityFormatter.text(grams: line.need, of: line.food))" : parts.joined(separator: " · ")
    }
}
