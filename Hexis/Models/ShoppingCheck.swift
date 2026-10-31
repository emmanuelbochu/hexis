import Foundation
import SwiftData

/// An item ticked in the shopping list; only checks of the current cycle count, so the list resets by itself.
@Model
final class ShoppingCheck {
    var ingredientID: UUID
    var cycleStart: Date

    init(ingredientID: UUID, cycleStart: Date) {
        self.ingredientID = ingredientID
        self.cycleStart = cycleStart
    }
}
