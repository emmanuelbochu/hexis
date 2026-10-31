import Foundation
import SwiftData

/// Something to buy this week only, off the plan (washing powder, a sponge, olive oil…): typed freely, tidied by the AI,
/// gone by itself when the next shopping cycle starts.
@Model
final class ShoppingNote {
    var emoji: String
    var name: String
    var quantity: String
    var cycleStart: Date
    var checked: Bool
    var createdAt: Date

    init(emoji: String, name: String, quantity: String = "", cycleStart: Date, checked: Bool = false, createdAt: Date = .now) {
        self.emoji = emoji
        self.name = name
        self.quantity = quantity
        self.cycleStart = cycleStart
        self.checked = checked
        self.createdAt = createdAt
    }
}
