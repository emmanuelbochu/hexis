import Foundation
import SwiftData

@Model
final class TemplateExercise {
    var order: Int
    var exerciseID: UUID
    var sets: Int
    var repsMin: Int
    var repsMax: Int
    var restSeconds: Int
    var targetRIR: Int
    var setupNotes: String
    var tempo: String
    var progressionStep: Double
    var block: TemplateBlock?

    init(
        order: Int, exerciseID: UUID, sets: Int, repsMin: Int, repsMax: Int,
        restSeconds: Int = 90, targetRIR: Int = 2, setupNotes: String = "",
        tempo: String = "", progressionStep: Double = 2.5
    ) {
        self.order = order
        self.exerciseID = exerciseID
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
        self.targetRIR = targetRIR
        self.setupNotes = setupNotes
        self.tempo = tempo
        self.progressionStep = progressionStep
    }
}
