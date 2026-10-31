import SwiftUI

/// Floating rest countdown at the bottom, a glass capsule like a mini player: −15 s, remaining time, +15 s, skip.
struct RestBar: View {
    let rest: RestTimer

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button { rest.add(seconds: -15) } label: {
                Text("−15").frame(minWidth: 44, minHeight: Theme.Layout.minTapHeight).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let end = rest.endDate {
                Text(timerInterval: Date.now...max(end, Date.now), countsDown: true)
                    .font(Theme.Fonts.title.monospacedDigit())
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
            }
            Button { rest.add(seconds: 15) } label: {
                Text("+15").frame(minWidth: 44, minHeight: Theme.Layout.minTapHeight).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { rest.skip() } label: {
                Image(systemName: "forward.fill")
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: Theme.Layout.minTapHeight, height: Theme.Layout.minTapHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Passer le repos")
        }
        .font(Theme.Fonts.headline)
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.leading, Theme.Spacing.m)
        .padding(.trailing, Theme.Spacing.xs)
        .frame(minHeight: Theme.Layout.minTapHeight + Theme.Spacing.s)
        .glassEffect(.regular.interactive(), in: .capsule)
        .sensoryFeedback(.success, trigger: rest.isRunning) { old, new in old && !new }
    }
}

#Preview {
    let rest = RestTimer()
    rest.start(seconds: 90)
    return RestBar(rest: rest).padding().screenBackground().appAppearance()
}
