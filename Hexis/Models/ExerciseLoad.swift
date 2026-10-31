import Foundation
import SwiftData

/// How the weight of an exercise is typed (per side, stack, per dumbbell, total). One per exercise.
@Model
final class ExerciseLoad {
    @Attribute(.unique) var exerciseID: UUID
    var kindRaw: String
    /// Weight added to the typed one on top of the two sides: the bar (20 kg) or 0 for a machine.
    var baseWeight: Double

    var kind: LoadKind { LoadKind(rawValue: kindRaw) ?? .total }

    init(exerciseID: UUID, kind: LoadKind, baseWeight: Double) {
        self.exerciseID = exerciseID
        self.kindRaw = kind.rawValue
        self.baseWeight = baseWeight
    }
}
