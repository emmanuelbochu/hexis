import Foundation

/// Human quantity text for a food: pieces, grams or kilograms.
enum QuantityFormatter {
    /// "4 œufs", "110 g" or "1,4 kg" depending on the food.
    static func text(grams: Double, of food: Ingredient) -> String {
        if food.pieceGrams > 0 {
            let count = Int((grams / food.pieceGrams).rounded())
            return "\(count) \(food.pieceLabel)\(count > 1 ? "s" : "")"
        }
        return weight(grams)
    }

    /// What is at home, in the unit it is bought in: « 3 boîtes » for what is counted in pieces, « 3 × 650 g » when the
    /// stock is a whole number of packs, else the weight.
    static func stock(_ food: Ingredient) -> String {
        if food.pieceGrams > 0 { return text(grams: food.stockGrams, of: food) }
        guard food.packGrams > 0, food.stockGrams >= food.packGrams else { return weight(food.stockGrams) }
        let packs = food.stockGrams / food.packGrams
        return abs(packs - packs.rounded()) < 0.08 ? "\(Int(packs.rounded())) × \(weight(food.packGrams))" : weight(food.stockGrams)
    }

    static func weight(_ grams: Double) -> String {
        guard grams >= 1000 else { return "\(Int(grams.rounded())) g" }
        return (grams / 1000).formatted(.number.precision(.fractionLength(0...2))) + " kg"
    }

    static func price(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR"))
    }
}
