import SwiftUI

/// Today: the weight (7-day average) and whether the bulk goes as planned, in two lines.
struct WeightCard: View {
    @State private var status: WeightStatus?
    @State private var missing: String?

    var body: some View {
        VStack(spacing: 0) {
            if let status {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(status.average.formatted(.number.precision(.fractionLength(1)))) kg")
                            .font(Theme.Fonts.largeTitle.monospacedDigit())
                        Text("moyenne 7 jours").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    verdict(status)
                }
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            } else if let missing {
                Label(missing, systemImage: "scalemass")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .task(id: Calendar.current.startOfDay(for: .now)) {
            await HealthService.authorize()
            let weights = await HealthService.weights(since: .now.addingTimeInterval(-35 * 86_400))
            status = WeightStatus.make(weights: weights, phase: NutritionGoals.phase)
            missing = status?.verdict == nil ? PhaseCheck.missing(weights) : nil
        }
    }

    @ViewBuilder private func verdict(_ status: WeightStatus) -> some View {
        let rate = status.perWeek.map { "\($0 >= 0 ? "+" : "")\($0.formatted(.number.precision(.fractionLength(2)))) kg/sem." } ?? ""
        switch status.verdict {
        case .onTrack:
            Label("\(status.phase.title) en bonne voie · \(rate)", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.Colors.accent)
        case .tooSlow:
            Label("\(status.phase.title) trop lente · \(rate)", systemImage: "arrow.down.right.circle.fill").foregroundStyle(Theme.Colors.textSecondary)
        case .tooFast:
            Label("\(status.phase.title) trop rapide · \(rate)", systemImage: "arrow.up.right.circle.fill").foregroundStyle(Theme.Colors.textSecondary)
        case nil:
            Text(missing ?? "").foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    WeightCard().padding().screenBackground().appAppearance()
}
