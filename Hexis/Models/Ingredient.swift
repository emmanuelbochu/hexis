import Foundation
import SwiftData

/// A food of the plan: macros per 100 g, how it is bought, and what is already at home.
@Model
final class Ingredient {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var category: String
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    /// Weight of one piece (egg, banana, can); 0 when the food is counted in grams.
    var pieceGrams: Double
    var pieceLabel: String
    /// Size of one purchasable pack in grams; 0 means the price is per kg.
    var packGrams: Double
    var packPrice: Double
    var stockGrams: Double

    init(
        id: UUID = UUID(), name: String, emoji: String, category: String,
        kcal: Double, protein: Double, carbs: Double, fat: Double,
        pieceGrams: Double = 0, pieceLabel: String = "", packGrams: Double = 0,
        packPrice: Double = 0, stockGrams: Double = 0
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.pieceGrams = pieceGrams
        self.pieceLabel = pieceLabel
        self.packGrams = packGrams
        self.packPrice = packPrice
        self.stockGrams = stockGrams
    }
}
