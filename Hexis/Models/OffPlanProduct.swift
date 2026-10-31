import Foundation
import SwiftData

/// An off-plan receipt line the user explained once: what the printed line is, in clean words, and its category.
/// The next ticket with the same printed line comes out named right.
@Model
final class OffPlanProduct {
    var label: String
    var name: String
    var category: String
    var seen: Int
    var lastSeen: Date

    init(label: String, name: String, category: String, seen: Int = 1, lastSeen: Date = .now) {
        self.label = label
        self.name = name
        self.category = category
        self.seen = seen
        self.lastSeen = lastSeen
    }
}
