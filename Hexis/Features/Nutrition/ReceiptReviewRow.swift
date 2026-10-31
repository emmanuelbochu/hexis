import SwiftUI

/// One plan line of the receipt: tick, food (tap to pick another), what the AI read struck out when it was changed, quantity and price.
struct ReceiptReviewRow: View {
    @Binding var line: ReceiptReviewLine
    let foods: [Ingredient]
    let onEdit: () -> Void
    let onPick: (Ingredient) -> Void
    let onMoveOut: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button { line.isSelected.toggle() } label: {
                Image(systemName: line.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(line.isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .frame(width: 36, height: Theme.Layout.minTapHeight)
            }
            .buttonStyle(.plain)
            Menu {
                Button("Pas dans le plan (dépenses)", systemImage: "tray", action: onMoveOut)
                ForEach(Dictionary(grouping: foods, by: \.category).keys.sorted(), id: \.self) { category in
                    Menu(category) {
                        ForEach(foods.filter { $0.category == category }) { food in
                            Button("\(food.emoji) \(food.name)") { onPick(food) }
                        }
                    }
                }
            } label: { title }
            Spacer()
            Button(action: onEdit) { amounts }.buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .frame(minHeight: Theme.Layout.minTapHeight)
        .cardStyle()
        .opacity(line.isSelected ? 1 : 0.6)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("\(line.match.food.emoji) \(line.match.food.name)").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
            if !line.match.label.isEmpty {
                Text(line.match.label).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1)
            }
            if let warning = line.warning {
                Label(warning.text, systemImage: "exclamationmark.triangle.fill").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .multilineTextAlignment(.leading)
    }

    /// The count and total as counted, with the AI's reading struck out above when the user changed it.
    private var amounts: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
            if line.isChanged {
                Text("\(line.original.quantityText) · \(QuantityFormatter.price(line.original.price))")
                    .strikethrough().foregroundStyle(Theme.Colors.textSecondary)
            }
            Text("+ " + line.match.quantityText).foregroundStyle(Theme.Colors.accent).underline(pattern: .dot)
            Text(QuantityFormatter.price(line.match.price)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .font(Theme.Fonts.caption)
    }
}
