import Foundation
import SwiftData

/// A correction learned from a receipt: this printed line is that food. Applied before the AI answer on later scans.
@Model
final class ReceiptAlias {
    var label: String
    var ingredientID: UUID
    var createdAt: Date

    init(label: String, ingredientID: UUID, createdAt: Date = .now) {
        self.label = label
        self.ingredientID = ingredientID
        self.createdAt = createdAt
    }
}
