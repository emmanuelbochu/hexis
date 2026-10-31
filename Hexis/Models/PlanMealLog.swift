import Foundation
import SwiftData

/// A planned meal validated on a given day, with the food entry it created.
@Model
final class PlanMealLog {
    var planMealID: UUID
    var day: Date
    var entryID: UUID

    init(planMealID: UUID, day: Date, entryID: UUID) {
        self.planMealID = planMealID
        self.day = day
        self.entryID = entryID
    }
}
