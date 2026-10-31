import SwiftUI

/// The countdowns of the other steps still running, so a timer is never lost when the card moves on.
struct BatchRunningTimers: View {
    let steps: [BatchStep]
    let current: BatchStep?
    private let timers = BatchTimers.shared

    var body: some View {
        let others = timers.items.filter { $0.title != current?.title }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Minuteurs en cours").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                ForEach(others) { item in
                    BatchTimerRow(title: item.title, end: item.end, seconds: steps.first { $0.title == item.title }?.timerSeconds ?? 60) {
                        timers.stop(item.title)
                    }
                }
            }
        }
    }
}
