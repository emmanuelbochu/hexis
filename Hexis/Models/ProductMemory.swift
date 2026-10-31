import Foundation
import SwiftData

/// What the receipts taught about a product: the printed line, the food it is, the weight and price of one unit as printed
/// (VAT included). An empty `label` is the mark of a pack size the user typed by hand: scans never overwrite it.
@Model
final class ProductMemory {
    var label: String
    var ingredientID: UUID
    var unitGrams: Double
    var unitPrice: Double
    var seen: Int
    var lastSeen: Date

    init(label: String, ingredientID: UUID, unitGrams: Double, unitPrice: Double, seen: Int = 1, lastSeen: Date = .now) {
        self.label = label
        self.ingredientID = ingredientID
        self.unitGrams = unitGrams
        self.unitPrice = unitPrice
        self.seen = seen
        self.lastSeen = lastSeen
    }
}
