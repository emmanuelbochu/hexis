import SwiftUI

/// One table row: set label, previous performance, editable kg / reps, effort and the check button.
struct SetRow: View {
    /// Shared with the column titles so the table stays aligned.
    enum Column {
        static let label: CGFloat = 46
        static let kg: CGFloat = 58
        static let reps: CGFloat = 50
        static let effort: CGFloat = 46
        static let check: CGFloat = 44
    }

    let label: String
    let isWarmup: Bool
    let previous: String
    @Binding var weight: Double
    @Binding var reps: Int
    let rpe: Int?
    let targetRPE: Int
    let isDone: Bool
    let isCurrent: Bool
    var record: LiveRecord.Kind?
    let onEffort: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Fonts.headline)
                .foregroundStyle(isWarmup || isCurrent ? Theme.Colors.accent : Theme.Colors.textPrimary)
                .frame(width: Column.label)
                .overlay(alignment: .topTrailing) {
                    if record != nil {
                        Image(systemName: "medal.fill").font(.system(size: 11)).foregroundStyle(Theme.Colors.record)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            Text(previous)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            field(value: $weight, format: .number.precision(.fractionLength(0...2)), pad: .decimalPad, width: Column.kg)
            field(value: $reps, format: .number, pad: .numberPad, width: Column.reps)
            effortButton
            Button(action: onToggle) {
                Image(systemName: "checkmark")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(isDone ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
                    .frame(width: Column.check, height: 40)
                    .background(isDone ? Theme.Colors.accent : Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: isDone)
        }
        .frame(minHeight: 48)
        .padding(.horizontal, Theme.Spacing.s)
        .background(
            isDone ? Theme.Colors.accentSoft : isCurrent ? Theme.Colors.surfaceRaised : .clear,
            in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
        )
    }

    /// Effort cell: the chosen RPE in its gauge color, else the target faded. Empty for warmups.
    @ViewBuilder private var effortButton: some View {
        if isWarmup {
            Color.clear.frame(width: Column.effort, height: 40)
        } else {
            Button(action: onEffort) {
                // Hexis Elle reads the effort as reps still possible (0, 1, 2, 3+), not as a 1-10 scale.
                Text(Edition.isElle ? "+\(EffortScale.simpleIndex(rpe ?? targetRPE))" : "\(rpe ?? targetRPE)")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(rpe.map { Theme.Colors.effort($0) } ?? Theme.Colors.textSecondary.opacity(0.6))
                    .frame(width: Column.effort, height: 40)
                    .background(
                        rpe.map { Theme.Colors.effort($0).opacity(0.18) } ?? Theme.Colors.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    )
            }
        }
    }

    private func field<V: ParseableFormatStyle>(
        value: Binding<V.FormatInput>, format: V, pad: UIKeyboardType, width: CGFloat
    ) -> some View where V.FormatOutput == String {
        TextField("", value: value, format: format)
            .keyboardType(pad)
            .multilineTextAlignment(.center)
            .font(Theme.Fonts.headline)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: width, height: 40)
            .background(Theme.Colors.surfaceRaised.opacity(isDone ? 0 : 1), in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .disabled(isDone)
            .onAppear { SelectAllOnEdit.install() }
    }
}

#Preview {
    VStack {
        SetRow(label: "W1", isWarmup: true, previous: "–", weight: .constant(20), reps: .constant(12), rpe: nil, targetRPE: 8, isDone: true, isCurrent: false, onEffort: {}, onToggle: {})
        SetRow(label: "1", isWarmup: false, previous: "60×10", weight: .constant(60), reps: .constant(10), rpe: 8, targetRPE: 8, isDone: true, isCurrent: false, onEffort: {}, onToggle: {})
        SetRow(label: "2", isWarmup: false, previous: "60×9", weight: .constant(60), reps: .constant(10), rpe: nil, targetRPE: 8, isDone: false, isCurrent: true, onEffort: {}, onToggle: {})
    }
    .padding().screenBackground().appAppearance()
}
