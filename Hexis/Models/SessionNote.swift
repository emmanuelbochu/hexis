import Foundation
import SwiftData

/// Free note and pain flag for one exercise in one session; `exerciseID == nil` is the whole-session note.
@Model
final class SessionNote {
    var sessionID: UUID
    var exerciseID: UUID?
    var text: String
    var hasPain: Bool
    var createdAt: Date

    init(sessionID: UUID, exerciseID: UUID? = nil, text: String = "", hasPain: Bool = false, createdAt: Date = .now) {
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.text = text
        self.hasPain = hasPain
        self.createdAt = createdAt
    }
}
