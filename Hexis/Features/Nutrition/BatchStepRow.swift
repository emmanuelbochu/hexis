import SwiftUI

/// A step other than the current one: its title, and one tap unfolds what it says (to read ahead, or check a quantity).
struct BatchStepRow: View {
    let step: BatchStep
    let done: Bool
    @AppStorage(PlanAutoAdjust.scaleKey) private var starchScale = 1.0
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button { withAnimation(.snappy) { open.toggle() } } label: {
                HStack {
                    if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Colors.accent) }
                    Text(step.title).font(Theme.Fonts.body).foregroundStyle(done ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    Spacer()
                    if step.timerSeconds > 0 {
                        Text(BatchTimerControl.text(step.timerSeconds)).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0)).foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(minHeight: Theme.Layout.minTapHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                Text(BatchScaling.detail(of: step, scale: starchScale))
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if step.timerSeconds > 0 && !done { BatchTimerControl(step: step) }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, open ? Theme.Spacing.s : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .sensoryFeedback(.selection, trigger: open)
    }
}

#Preview {
    BatchStepRow(step: BatchStep(order: 0, title: "Pâtes", detail: "535 g de pâtes.", timerSeconds: 0), done: false)
        .padding()
        .appAppearance()
}
