import SwiftUI

/// Progress and estimated budget of the list.
struct ShoppingSummaryCard: View {
    let lines: [ShoppingLine]

    var body: some View {
        let done = lines.filter(\.checked)
        let total = lines.reduce(0) { $0 + $1.cost }
        let missing = lines.filter { $0.cost == 0 }.count
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("\(done.count)/\(lines.count) articles")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(QuantityFormatter.price(total))
                    .font(Theme.Fonts.headline.monospacedDigit())
                    .foregroundStyle(Theme.Colors.accent)
            }
            ProgressView(value: lines.isEmpty ? 0 : Double(done.count) / Double(lines.count))
                .tint(Theme.Colors.accent)
            Text(footnote(spent: done.reduce(0) { $0 + $1.cost }, missing: missing))
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .cardStyle()
    }

    private func footnote(spent: Double, missing: Int) -> String {
        let spentText = "Dans le panier : \(QuantityFormatter.price(spent))"
        return missing > 0 ? "\(spentText) · \(missing) prix manquants (appui long sur un article)" : spentText
    }
}
