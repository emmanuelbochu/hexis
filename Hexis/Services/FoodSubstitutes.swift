import Foundation

/// Foods the shop sometimes does not have, and the one bought instead (sardines → mackerel): the substitute counts as the food
/// on the list, is shown next to it, and is accepted when the receipt is read.
enum FoodSubstitutes {
    private static let table = ["sardine": "maquereau"]

    static func alternative(for food: Ingredient) -> String? {
        let name = food.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "fr_FR"))
        return table.first { name.contains($0.key) }?.value
    }

    /// « Sardines à l'huile » → « Sardines à l'huile ou maquereau ».
    static func title(_ food: Ingredient) -> String {
        alternative(for: food).map { "\(food.name) ou \($0)" } ?? food.name
    }
}
