import Charts
import SwiftData
import SwiftUI

/// The spending: this week at a glance, the last weeks, where the money goes, what protein costs, which prices moved.
struct SpendingStatsView: View {
    @Query private var purchases: [PurchaseLog]
    @Query private var extras: [ExtraPurchase]
    @Query private var foods: [Ingredient]

    var body: some View {
        let stats = SpendingStats(purchases: purchases, extras: extras, foods: foods)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if stats.isEmpty {
                    Label("Scanne un ticket pour voir tes dépenses.", systemImage: "doc.text.viewfinder")
                        .font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    hero(stats)
                    weeksChart(stats)
                    if let average = stats.weeklyAverage, let daily = stats.dailyAverage {
                        HStack(spacing: Theme.Spacing.m) {
                            tile("Semaine type", QuantityFormatter.price(average), symbol: "calendar")
                            tile("Par jour", QuantityFormatter.price(daily), symbol: "sun.max")
                        }
                    }
                    SpendingSharesCard(shares: stats.shares)
                    SpendingProteinCard(costs: stats.proteinCosts)
                    SpendingMoversCard(movers: stats.movers)
                }
                NavigationLink { TicketsView() } label: {
                    HStack {
                        Label("Tous les tickets", systemImage: "doc.text").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(minHeight: Theme.Layout.minTapHeight)
                    .cardStyle()
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.m)
        }
        .screenBackground()
        .navigationTitle("Dépenses")
    }

    private func hero(_ stats: SpendingStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Cette semaine").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            Text(QuantityFormatter.price(stats.thisWeek?.total ?? 0)).font(Theme.Fonts.bigNumber).foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: Theme.Spacing.s) {
                if let change = stats.versusUsual, abs(change) >= 0.03 {
                    Label("\(change > 0 ? "+" : "")\(Int((change * 100).rounded())) % vs semaine type", systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, Theme.Spacing.s).padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.accentSoft, in: Capsule())
                }
                Text("\(stats.tickets) ticket\(stats.tickets > 1 ? "s" : "") · \(QuantityFormatter.price(stats.thisWeek?.extra ?? 0)) hors plan")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func weeksChart(_ stats: SpendingStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("8 dernières semaines").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            Chart {
                ForEach(stats.weeks) { week in
                    BarMark(x: .value("Semaine", week.start, unit: .weekOfYear), y: .value("Total", week.total))
                        .foregroundStyle(week.id == stats.thisWeek?.id ? Theme.Colors.accent : Theme.Colors.accent.opacity(0.4))
                        .cornerRadius(6)
                }
                if let average = stats.weeklyAverage {
                    RuleMark(y: .value("Semaine type", average))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) { AxisValueLabel(format: .dateTime.day()) } }
            .chartYAxis { AxisMarks(position: .trailing) { AxisValueLabel() } }
            .frame(height: 170)
        }
        .padding(Theme.Spacing.m)
        .cardStyle()
    }

    private func tile(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Image(systemName: symbol).foregroundStyle(Theme.Colors.accent)
            Text(value).font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    NavigationStack { SpendingStatsView() }
        .modelContainer(for: [PurchaseLog.self, ExtraPurchase.self, Ingredient.self], inMemory: true)
        .appAppearance()
}
