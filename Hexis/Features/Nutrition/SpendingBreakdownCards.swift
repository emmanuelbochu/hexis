import SwiftUI

/// Where the last 4 weeks of money went, as proportional bars.
struct SpendingSharesCard: View {
    let shares: [SpendingStats.Share]

    var body: some View {
        let total = shares.reduce(0) { $0 + $1.total }
        if total > 0 {
            card("Où part l'argent · 4 semaines") {
                ForEach(shares.prefix(6)) { share in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Text(share.name).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text("\(QuantityFormatter.price(share.total)) · \(Int((share.total / total * 100).rounded())) %")
                                .font(Theme.Fonts.caption.monospacedDigit()).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        GeometryReader { proxy in
                            Capsule().fill(Theme.Colors.accent).frame(width: max(6, proxy.size.width * share.total / total))
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}

/// What 100 g of protein costs from the cheapest sources (price from the pantry crossed with the food's protein).
struct SpendingProteinCard: View {
    let costs: [SpendingStats.ProteinCost]

    var body: some View {
        if !costs.isEmpty {
            card("100 g de protéines") {
                ForEach(costs) { cost in
                    HStack {
                        Text("\(cost.emoji) \(cost.name)").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(QuantityFormatter.price(cost.euros)).font(Theme.Fonts.headline.monospacedDigit()).foregroundStyle(Theme.Colors.accent)
                    }
                }
            }
        }
    }
}

/// Foods whose price per kilo moved by 10 % or more.
struct SpendingMoversCard: View {
    let movers: [SpendingStats.Mover]

    var body: some View {
        if !movers.isEmpty {
            card("Prix qui bougent") {
                ForEach(movers) { mover in
                    HStack {
                        Text("\(mover.emoji) \(mover.name)").font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Label("\(mover.change > 0 ? "+" : "")\(Int((mover.change * 100).rounded())) %", systemImage: mover.change > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(Theme.Fonts.caption.monospacedDigit()).foregroundStyle(Theme.Colors.accent)
                        Text("\(QuantityFormatter.price(mover.latest))/kg").font(Theme.Fonts.caption.monospacedDigit()).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
        Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        content()
    }
    .padding(Theme.Spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle()
}
