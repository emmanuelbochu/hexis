import Foundation
import SwiftData

/// One exercise, or a superset (1a/1b) when it holds several.
@Model
final class TemplateBlock {
    var order: Int
    /// Superset scheme: rounds of (1a + 1b) before the extra sets of 1a alone.
    var supersetRounds: Int?
    var extraSetsOfFirst: Int?
    var template: WorkoutTemplate?
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.block)
    var exercises: [TemplateExercise] = []

    init(order: Int, supersetRounds: Int? = nil, extraSetsOfFirst: Int? = nil) {
        self.order = order
        self.supersetRounds = supersetRounds
        self.extraSetsOfFirst = extraSetsOfFirst
    }
}
