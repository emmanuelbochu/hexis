import SwiftUI

/// Three figures to read at a glance: strength over the last weeks, weight over 4 weeks, sessions this week.
struct JourneyCard: View {
    let journey: Journey

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Tes \(journey.weeks) dernières semaines").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                figure(journey.strength.map(Self.percent), "Force", good: (journey.strength ?? 0) > 0)
                if Edition.usesHealth { figure(journey.weightChange.map(Self.kilos), "Poids · 4 sem.", good: (journey.weightChange ?? 0) > 0) }
                figure("\(journey.thisWeek)/\(journey.weeklyTarget)", "Cette semaine", good: journey.thisWeek >= journey.weeklyTarget)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func figure(_ value: String?, _ title: String, good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value ?? "–")
                .font(Theme.Fonts.title.monospacedDigit())
                .foregroundStyle(value != nil && good ? Theme.Colors.accent : Theme.Colors.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func percent(_ fraction: Double) -> String {
        let value = Int((fraction * 100).rounded())
        return "\(value > 0 ? "+" : "")\(value) %"
    }

    private static func kilos(_ kg: Double) -> String {
        "\(kg > 0.05 ? "+" : "")\(kg.formatted(.number.precision(.fractionLength(1)))) kg"
    }
}

#Preview {
    JourneyCard(journey: Journey(weeks: 12, strength: 0.09, measured: 20, weightChange: 0.4, thisWeek: 2, weeklyTarget: 4))
        .padding()
        .screenBackground()
        .appAppearance()
}
