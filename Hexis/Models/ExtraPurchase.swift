import Foundation
import SwiftData

/// A food line of a scanned receipt that is not in the plan: kept so the spending is complete.
@Model
final class ExtraPurchase {
    var label: String
    var category: String
    var price: Double
    var date: Date

    init(label: String, category: String, price: Double, date: Date = .now) {
        self.label = label
        self.category = category
        self.price = price
        self.date = date
    }
}
