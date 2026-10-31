import SwiftUI

/// Weight (Withings via Health) and steps for the week shown; hidden until Health has data.
struct BodyCard: View {
    let weekEnd: Date
    @State private var trend: BodyTrend?

    var body: some View {
        VStack(spacing: 0) {
            if let trend, trend.weight != nil || trend.steps != nil { card(trend) }
        }
        .task(id: weekEnd) { await load() }
    }

    private func card(_ trend: BodyTrend) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Corps").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
            if let weight = trend.weight {
                row("scalemass.fill", String(format: "%.1f kg", weight), detail: weightDetail(trend))
            }
            if let steps = trend.steps {
                row("figure.walk", "\(steps.formatted()) pas/jour", detail: stepsDetail(trend, steps))
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func row(_ icon: String, _ value: String, detail: String?) -> some View {
        HStack {
            Label(value, systemImage: icon).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if let detail { Text(detail).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.accent) }
        }
    }

    private func weightDetail(_ trend: BodyTrend) -> String? {
        guard let change = trend.weightChange else { return nil }
        return String(format: "%+.1f kg vs sem. préc.", change)
    }

    private func stepsDetail(_ trend: BodyTrend, _ steps: Int) -> String? {
        guard let before = trend.previousSteps, before > 0 else { return nil }
        let percent = Int((Double(steps - before) / Double(before) * 100).rounded())
        return "\(percent >= 0 ? "+" : "")\(percent) % vs sem. préc."
    }

    private func load() async {
        await HealthService.authorize()
        let since = Calendar.current.date(byAdding: .day, value: -21, to: weekEnd) ?? weekEnd
        async let weights = HealthService.weights(since: since)
        async let steps = HealthService.dailySteps(since: since)
        trend = BodyTrend(weights: await weights, steps: await steps, end: weekEnd)
    }
}
