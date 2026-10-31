import Foundation
import SwiftData

/// One line of a scanned shopping receipt matched to a food: what was bought, how much, for how much.
@Model
final class PurchaseLog {
    var ingredientID: UUID
    var date: Date
    var grams: Double
    var price: Double

    init(ingredientID: UUID, date: Date = .now, grams: Double, price: Double) {
        self.ingredientID = ingredientID
        self.date = date
        self.grams = grams
        self.price = price
    }
}
