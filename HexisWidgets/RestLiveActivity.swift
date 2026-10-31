import ActivityKit
import SwiftUI
import WidgetKit

#if ELLE
private let accent = Color(red: 0xE3 / 255, green: 0xA8 / 255, blue: 0x9B / 255)
#else
private let accent = Color(red: 0x7B / 255, green: 0x8C / 255, blue: 0xFF / 255)
#endif

/// Countdown of the rest: lock screen banner and Dynamic Island.
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.isStale ? doneText(context) : context.state.title ?? "Repos").font(.subheadline).foregroundStyle(.secondary)
                    Text(context.state.next).font(.headline).lineLimit(1)
                }
                Spacer()
                RestCountdown(context: context).font(.system(size: 40, weight: .semibold, design: .rounded))
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: symbol(context)).font(.title2).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(context: context).font(.system(size: 34, weight: .semibold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.isStale ? doneText(context) : context.state.next).font(.headline).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: symbol(context)).foregroundStyle(accent)
            } compactTrailing: {
                RestCountdown(context: context).frame(width: 46).font(.system(.callout, design: .rounded).weight(.semibold))
            } minimal: {
                Image(systemName: symbol(context)).foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}

private func symbol(_ context: ActivityViewContext<RestActivityAttributes>) -> String {
    context.state.title == nil ? "timer" : "frying.pan.fill"
}

private func doneText(_ context: ActivityViewContext<RestActivityAttributes>) -> String {
    context.state.title == nil ? "Repos terminé" : "\(context.state.next) : c'est l'heure"
}

private struct RestCountdown: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        if context.isStale {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
        } else {
            // No hours column: « 1:04 », never « 0:01:04 » cut in the Dynamic Island.
            Text(timerInterval: Date.now...max(context.state.endDate, .now), countsDown: true, showsHours: false)
                .monospacedDigit().multilineTextAlignment(.trailing).foregroundStyle(accent)
        }
    }
}
