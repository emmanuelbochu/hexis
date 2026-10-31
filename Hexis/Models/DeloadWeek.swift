import Foundation
import SwiftData

/// A planned lighter week (loads −10 %), validated by the user.
@Model
final class DeloadWeek {
    /// Monday of the week.
    @Attribute(.unique) var start: Date
    var reason: String
    var createdAt: Date

    init(start: Date, reason: String, createdAt: Date = .now) {
        self.start = start
        self.reason = reason
        self.createdAt = createdAt
    }
}
