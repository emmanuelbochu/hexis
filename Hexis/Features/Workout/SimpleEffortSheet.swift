import SwiftUI

/// Hexis Elle's effort question: how many more reps could she have done? One tap validates the set.
struct SimpleEffortSheet: View {
    @Environment(\.dismiss) private var dismiss
    let suggested: Int
    let onValidate: (Int) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("Tu aurais pu en faire combien de plus ?")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            ForEach(Array(EffortScale.simple.enumerated()), id: \.offset) { index, option in
                Button {
                    onValidate(option.rpe)
                    dismiss()
                } label: {
                    Text(option.label)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minTapHeight)
                        .background(Theme.Colors.surfaceRaised, in: Capsule())
                        .overlay { Capsule().stroke(Theme.Colors.accent, lineWidth: index == EffortScale.simpleIndex(suggested) ? 2 : 0) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.m)
        .presentationDetents([.height(400)])
        .presentationBackground(Theme.Colors.surface)
        .sensoryFeedback(.selection, trigger: suggested)
    }
}

#Preview {
    SimpleEffortSheet(suggested: 8) { _ in }.appAppearance()
}
