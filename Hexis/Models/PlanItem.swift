import Foundation

/// One food of a planned meal, in grams.
struct PlanItem: Codable, Hashable {
    var ingredientID: UUID
    var grams: Double
}
