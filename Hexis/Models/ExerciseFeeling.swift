import Foundation
import SwiftData

/// The feeling chosen for one exercise in one session.
@Model
final class ExerciseFeeling {
    var sessionID: UUID
    var exerciseID: UUID
    var feelingRaw: String
    var createdAt: Date

    var feeling: Feeling? { Feeling(rawValue: feelingRaw) }
    /// « Fatigué » is said for the whole session: stored with the session id as exercise id.
    var isSessionWide: Bool { exerciseID == sessionID }

    init(sessionID: UUID, exerciseID: UUID, feeling: Feeling, createdAt: Date = .now) {
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.feelingRaw = feeling.rawValue
        self.createdAt = createdAt
    }
}
