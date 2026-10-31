import Foundation
import SwiftData

/// A planned meal of the weekly plan. `weekday` follows `Calendar` (1 = Sunday … 7 = Saturday).
@Model
final class PlanMeal {
    @Attribute(.unique) var id: UUID
    var weekday: Int
    var slotRaw: String
    var items: [PlanItem]

    var slot: MealSlot { MealSlot(rawValue: slotRaw) ?? .snack }

    init(id: UUID = UUID(), weekday: Int, slot: MealSlot, items: [PlanItem]) {
        self.id = id
        self.weekday = weekday
        self.slotRaw = slot.rawValue
        self.items = items
    }
}
