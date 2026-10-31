import Foundation
import SwiftData

/// How much of a food is at the flat (oil, oats, tuna live there and are carried only when they run low). The rest of the
/// food's stock is at home; `Ingredient.stockGrams` stays the total of both.
@Model
final class FlatStock {
    var ingredientID: UUID
    var grams: Double
    var updatedAt: Date

    init(ingredientID: UUID, grams: Double, updatedAt: Date = .now) {
        self.ingredientID = ingredientID
        self.grams = grams
        self.updatedAt = updatedAt
    }
}
