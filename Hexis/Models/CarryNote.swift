import Foundation
import SwiftData

/// Note for the next time an exercise is done: shown greyed in the next session, deleted in the one after.
@Model
final class CarryNote {
    var exerciseID: UUID
    /// Session in which the note was written.
    var sessionID: UUID
    var text: String
    var createdAt: Date
    /// Session in which the note was first shown greyed; nil until then.
    var carrySessionID: UUID?

    init(exerciseID: UUID, sessionID: UUID, text: String = "", createdAt: Date = .now, carrySessionID: UUID? = nil) {
        self.exerciseID = exerciseID
        self.sessionID = sessionID
        self.text = text
        self.createdAt = createdAt
        self.carrySessionID = carrySessionID
    }
}
