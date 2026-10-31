import Foundation
import SwiftData

/// What the user taught about the lines outside the plan: a printed line → a clean name and a category.
enum OffPlanBook {
    /// The extras named as the user explained them on an earlier ticket.
    static func named(_ extras: [ReceiptExtra], with products: [OffPlanProduct]) -> [ReceiptExtra] {
        let byLabel = Dictionary(products.map { ($0.label, $0) }, uniquingKeysWith: { first, _ in first })
        return extras.map { extra in
            guard let known = byLabel[ReceiptLabel.normalize(extra.printed)] else { return extra }
            var named = extra
            named.label = known.name
            named.category = known.category
            return named
        }
    }

    /// Remembers the extras the user explained (the latest explanation wins).
    static func learn(_ extras: [ReceiptExtra], in context: ModelContext, now: Date = .now) {
        let all = (try? context.fetch(FetchDescriptor<OffPlanProduct>())) ?? []
        for extra in extras where extra.edited {
            let key = ReceiptLabel.normalize(extra.printed)
            guard !key.isEmpty, !extra.label.isEmpty else { continue }
            if let known = all.first(where: { $0.label == key }) {
                known.name = extra.label
                known.category = extra.category
                known.seen += 1
                known.lastSeen = now
            } else {
                context.insert(OffPlanProduct(label: key, name: extra.label, category: extra.category, lastSeen: now))
            }
        }
    }
}
