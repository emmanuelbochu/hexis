import SwiftData
import SwiftUI

/// What the scanned receipts add up to this week, with the part outside the plan and the recent average.
struct SpendingCard: View {
    @Query private var purchases: [PurchaseLog]
    @Query private var extras: [ExtraPurchase]

    var body: some View {
        if let spending = Spending(purchases: purchases, extras: extras) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Label("Dépensé cette semaine", systemImage: "eurosign.circle.fill")
                        .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(QuantityFormatter.price(spending.thisWeek))
                        .font(Theme.Fonts.headline.monospacedDigit()).foregroundStyle(Theme.Colors.accent)
                }
                Text(detail(spending)).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                NavigationLink { SpendingStatsView() } label: {
                    Label("Dépenses et tickets", systemImage: "chart.bar")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
                        .frame(minHeight: Theme.Layout.minTapHeight, alignment: .leading)
                }
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private func detail(_ spending: Spending) -> String {
        var parts: [String] = []
        if spending.offPlan > 0 { parts.append("dont \(QuantityFormatter.price(spending.offPlan)) hors plan") }
        if let average = spending.average { parts.append("moyenne des 4 semaines avant : \(QuantityFormatter.price(average))") }
        return parts.isEmpty ? "Tickets scannés cette semaine" : parts.joined(separator: " · ")
    }
}
