import Foundation
import SwiftData

/// The products the receipts taught: what a printed line weighs and costs per unit, used to brief the AI, to fix its weights,
/// and to keep a pack size the user typed by hand.
enum ProductMemoryBook {
    /// One prompt line per product seen most often: `« label » = index · unit grams · unit price`.
    static func promptLines(_ memories: [ProductMemory], foods: [Ingredient], limit: Int = 40) -> [String] {
        memories.filter { !$0.label.isEmpty && $0.unitGrams > 0 }
            .sorted { ($0.seen, $0.lastSeen) > ($1.seen, $1.lastSeen) }.prefix(limit)
            .compactMap { memory in
                foods.firstIndex { $0.id == memory.ingredientID }.map {
                    "« \(memory.label) » = \($0) · \(Int(memory.unitGrams.rounded())) g l'unité · \(String(format: "%.2f", memory.unitPrice)) €"
                }
            }
    }

    /// The grams of a line whose product is known: units × the unit weight seen before, when the AI is off by more than 15 %.
    static func grams(_ answered: Double, units: Int?, label: String, food: Ingredient, in memories: [ProductMemory]) -> Double {
        guard let units, units >= 1, answered > 0 else { return answered }
        let key = ReceiptLabel.normalize(label)
        guard !key.isEmpty, let memory = memories.first(where: { $0.label == key && $0.ingredientID == food.id && $0.unitGrams > 0 }) else { return answered }
        let expected = Double(units) * memory.unitGrams
        return abs(answered - expected) > 0.15 * expected ? expected : answered
    }

    /// Remembers each bought line (latest weight and price per unit win: they were checked in the review).
    static func learn(_ matches: [ReceiptMatch], in context: ModelContext, now: Date = .now) {
        let all = (try? context.fetch(FetchDescriptor<ProductMemory>())) ?? []
        for match in matches {
            let key = ReceiptLabel.normalize(match.label)
            guard !key.isEmpty, let units = match.units, units >= 1, match.grams > 0 else { continue }
            let grams = match.grams / Double(units), price = match.price / Double(units)
            if let memory = all.first(where: { $0.label == key && $0.ingredientID == match.food.id }) {
                memory.unitGrams = grams
                if price > 0 { memory.unitPrice = price }
                memory.seen += 1
                memory.lastSeen = now
            } else {
                context.insert(ProductMemory(label: key, ingredientID: match.food.id, unitGrams: grams, unitPrice: price, lastSeen: now))
            }
        }
    }

    /// The pack a ticket line with a known count shows (grams ÷ count, to 5 g); false when it does not say or the size is the user's.
    @discardableResult
    static func learnPack(from match: ReceiptMatch, in context: ModelContext) -> Bool {
        let food = match.food
        guard food.packGrams > 0, food.pieceGrams <= 0 || match.soldInBoxes, let units = match.units, units >= 1, match.grams > 0,
              !isLocked(food.id, in: context) else { return false }
        food.packGrams = (match.grams / Double(units) / 5).rounded() * 5
        return true
    }

    /// The pack size is the user's now: scans stop changing it.
    static func lockPack(of food: Ingredient, in context: ModelContext) {
        let id = food.id
        let locks = (try? context.fetch(FetchDescriptor<ProductMemory>(predicate: #Predicate { $0.ingredientID == id && $0.label == "" }))) ?? []
        if let lock = locks.first { lock.unitGrams = food.packGrams; return }
        context.insert(ProductMemory(label: "", ingredientID: id, unitGrams: food.packGrams, unitPrice: 0))
    }

    static func isLocked(_ id: UUID, in context: ModelContext) -> Bool {
        let count = try? context.fetchCount(FetchDescriptor<ProductMemory>(predicate: #Predicate { $0.ingredientID == id && $0.label == "" }))
        return (count ?? 0) > 0
    }
}
