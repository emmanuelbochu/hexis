import SwiftUI

/// The step's countdown: one tap starts it, then it shows the time left on a bar (also in the Dynamic Island) and rings at the
/// end, even with the app closed. Several steps can run at once: the others keep going when this one starts.
struct BatchTimerControl: View {
    let step: BatchStep
    private let timers = BatchTimers.shared

    var body: some View {
        if let end = timers.end(of: step.title) {
            BatchTimerRow(title: nil, end: end, seconds: step.timerSeconds) { timers.stop(step.title) }
        } else {
            Button {
                timers.start(title: step.title, seconds: step.timerSeconds)
            } label: { Label("Minuteur \(Self.text(step.timerSeconds))", systemImage: "timer") }
                .buttonStyle(SecondaryButtonStyle())
                .sensoryFeedback(.start, trigger: timers.items.count)
        }
    }

    /// « 11 min », « 1 min 15 », « 45 s ».
    static func text(_ seconds: Int) -> String {
        let (m, s) = (seconds / 60, seconds % 60)
        if m == 0 { return "\(s) s" }
        return s == 0 ? "\(m) min" : "\(m) min \(String(format: "%02d", s))"
    }
}

/// A running countdown: time left in large digits, a bar that empties, a round stop button that never leaves the card.
struct BatchTimerRow: View {
    let title: String?
    let end: Date
    let seconds: Int
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: 0) {
                    if let title { Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1) }
                    Text(timerInterval: Date.now...max(end, .now), countsDown: true, showsHours: false)
                        .font(Theme.Fonts.title.monospacedDigit())
                        .foregroundStyle(Theme.Colors.accent)
                }
                Spacer(minLength: Theme.Spacing.s)
                Button(action: onStop) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Arrêter le minuteur")
            }
            ProgressView(timerInterval: end.addingTimeInterval(-Double(max(seconds, 1)))...max(end, .now), countsDown: true) {
                EmptyView()
            } currentValueLabel: { EmptyView() }
                .tint(Theme.Colors.accent)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Colors.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
    }
}

#Preview {
    BatchTimerControl(step: BatchStep(order: 0, title: "Riz", detail: "", timerSeconds: 75))
        .padding()
        .appAppearance()
}
