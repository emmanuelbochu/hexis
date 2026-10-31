import Foundation
import SwiftData

/// A short coach text written by Gemini, kept so the same moment is never paid for twice.
@Model
final class AIInsight {
    var kind: String
    var key: String
    var text: String
    var createdAt: Date

    init(kind: String, key: String, text: String, createdAt: Date = .now) {
        self.kind = kind
        self.key = key
        self.text = text
        self.createdAt = createdAt
    }
}
