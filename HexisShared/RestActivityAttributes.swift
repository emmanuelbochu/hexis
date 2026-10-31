import ActivityKit
import Foundation

/// Live Activity of a rest between sets or of a batch cooking step (shared by the app and the widget extension).
nonisolated struct RestActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var endDate: Date
        var next: String
        /// Shown instead of « Repos » (the batch cooking); nil for a rest.
        var title: String?
    }
}
