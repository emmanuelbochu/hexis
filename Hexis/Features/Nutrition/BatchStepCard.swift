import SwiftUI

/// The step to do now: what to do, its timer when it has one, then « Fait, suivante ».
struct BatchStepCard: View {
    let step: BatchStep
    let index: Int
    let total: Int
    let previous: BatchStep?
    @AppStorage(PlanAutoAdjust.scaleKey) private var starchScale = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Étape \(index)/\(total)")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.accent)
            Text(step.title)
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(BatchScaling.detail(of: step, scale: starchScale))
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            if step.timerSeconds > 0 { BatchTimerControl(step: step) }
            Button {
                step.completedAt = .now
            } label: { Label("Fait, suivante", systemImage: "checkmark") }
                .buttonStyle(PrimaryButtonStyle())
            if let previous {
                Button("Revenir à « \(previous.title) »") { previous.completedAt = nil }
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
            }
        }
        .padding(Theme.Spacing.m)
        .cardStyle()
    }
}

#Preview {
    BatchStepCard(step: BatchStep(order: 0, title: "Ratatouille", detail: "Poêle large, feu vif.", timerSeconds: 660), index: 1, total: 3, previous: nil)
        .padding()
        .appAppearance()
}
