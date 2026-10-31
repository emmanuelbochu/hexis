import ActivityKit
import Foundation

/// Dynamic Island / lock screen countdown of the current rest.
@MainActor
enum RestActivity {
    static func show(until date: Date, next: String, title: String? = nil) {
        let state = RestActivityAttributes.ContentState(endDate: date, next: next, title: title)
        let content = ActivityContent(state: state, staleDate: date)
        if let current = Activity<RestActivityAttributes>.activities.first {
            Task { await current.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: RestActivityAttributes(), content: content)
        }
    }

    static func end() {
        for activity in Activity<RestActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
