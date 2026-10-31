import SwiftUI

/// Effort gauge: drag the dot along the green → red bar, then validate the set with that effort.
struct EffortGaugeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var rpe: Int
    let onValidate: (Int) -> Void

    private let knob: CGFloat = 34

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("\(rpe)")
                    .font(Theme.Fonts.bigNumber)
                    .foregroundStyle(Theme.Colors.effort(rpe))
                Text(EffortScale.title(rpe)).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(EffortScale.detail(rpe)).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            .animation(.snappy, value: rpe)
            gauge
            Button("Valider la série") {
                onValidate(rpe)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Spacing.m)
        .presentationDetents([.height(360)])
        .presentationBackground(Theme.Colors.surface)
    }

    private var gauge: some View {
        GeometryReader { geo in
            let track = geo.size.width - knob
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: (1...10).map { Theme.Colors.effort($0) }, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 12)
                    .padding(.horizontal, knob / 2)
                Circle()
                    .fill(Theme.Colors.textPrimary)
                    .overlay(Circle().stroke(Theme.Colors.effort(rpe), lineWidth: 5))
                    .frame(width: knob, height: knob)
                    .offset(x: track * CGFloat(rpe - 1) / 9)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    let ratio = (value.location.x - knob / 2) / max(track, 1)
                    rpe = min(max(Int((ratio * 9).rounded()) + 1, 1), 10)
                }
            )
        }
        .frame(height: 48)
        .sensoryFeedback(.selection, trigger: rpe)
    }
}

#Preview {
    EffortGaugeSheet(rpe: 8) { _ in }.appAppearance()
}
