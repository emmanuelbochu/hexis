import SwiftUI

/// Deload suggestion (one tap to plan it) or the running / planned deload week.
struct DeloadCard: View {
    enum Mode {
        case advice(DeloadAdvice, plan: () -> Void)
        case planned(start: Date, isCurrent: Bool)
    }

    let mode: Mode

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            switch mode {
            case let .advice(advice, plan):
                Label("Déload conseillé · semaine du \(date(advice.weekStart))", systemImage: "arrow.down.right.circle.fill")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.accent)
                Text(detail(advice))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Button("Planifier", action: plan).buttonStyle(PrimaryButtonStyle())
            case let .planned(start, isCurrent):
                Label(
                    isCurrent ? "Semaine de déload : mêmes charges, moitié des séries" : "Déload planifié · semaine du \(date(start))",
                    systemImage: "arrow.down.right.circle.fill"
                )
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func date(_ day: Date) -> String { day.formatted(.dateTime.day().month(.abbreviated)) }

    private func detail(_ advice: DeloadAdvice) -> String {
        let base = advice.reason + " Une semaine avec les mêmes charges et moitié des séries."
        return advice.holiday.map { "\(base) Ça tombe pendant les \($0)." } ?? base
    }
}
