import Foundation
import SwiftData

/// A lasting change the app made by itself to one exercise of the program in one gym, after a plateau:
/// one set added (priority muscle) or the rep range moved. Cleared when a new program is loaded.
@Model
final class ExerciseTweak {
    var exerciseID: UUID
    var gymID: UUID?
    var setsDelta: Int
    /// Added to both ends of the planned rep range.
    var repsShift: Int
    var since: Date
    var reason: String

    init(exerciseID: UUID, gymID: UUID?, setsDelta: Int = 0, repsShift: Int = 0, since: Date = .now, reason: String = "") {
        self.exerciseID = exerciseID
        self.gymID = gymID
        self.setsDelta = setsDelta
        self.repsShift = repsShift
        self.since = since
        self.reason = reason
    }
}
