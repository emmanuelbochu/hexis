import Foundation
import SwiftData

/// One note per exercise and per gym (seat height, machine setup...).
@Model
final class ExerciseGymNote {
    var exerciseID: UUID
    var gymID: UUID
    var note: String

    init(exerciseID: UUID, gymID: UUID, note: String) {
        self.exerciseID = exerciseID
        self.gymID = gymID
        self.note = note
    }
}
