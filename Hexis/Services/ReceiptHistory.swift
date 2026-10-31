import Foundation
import SwiftData

/// One scanned receipt, rebuilt from the lines it left: plan foods (`PurchaseLog`) and the rest (`ExtraPurchase`) added in the same minutes.
struct ReceiptTicket: Identifiable {
    var date: Date
    var purchases: [PurchaseLog]
    var extras: [ExtraPurchase]

    var id: Date { date }
    var total: Double { purchases.reduce(0) { $0 + $1.price } + extras.reduce(0) { $0 + $1.price } }
}

enum ReceiptHistory {
    /// Lines further apart than this belong to two different scans.
    static let gap: TimeInterval = 10 * 60

    /// Tickets, newest first.
    static func tickets(purchases: [PurchaseLog], extras: [ExtraPurchase]) -> [ReceiptTicket] {
        let stamped = purchases.map { (date: $0.date, purchase: Optional($0), extra: Optional<ExtraPurchase>.none) }
            + extras.map { (date: $0.date, purchase: Optional<PurchaseLog>.none, extra: Optional($0)) }
        var tickets: [ReceiptTicket] = []
        var lastDate = Date.distantFuture
        for item in stamped.sorted(by: { $0.date > $1.date }) {
            if tickets.isEmpty || lastDate.timeIntervalSince(item.date) > gap {
                tickets.append(ReceiptTicket(date: item.date, purchases: [], extras: []))
            }
            lastDate = item.date
            if let purchase = item.purchase { tickets[tickets.count - 1].purchases.append(purchase) }
            if let extra = item.extra { tickets[tickets.count - 1].extras.append(extra) }
        }
        return tickets
    }

    /// A line of a ticket retyped by hand: the stock follows the difference (never below zero).
    static func correct(_ log: PurchaseLog, grams: Double, price: Double, food: Ingredient?) {
        food?.stockGrams = max(0, (food?.stockGrams ?? 0) + grams - log.grams)
        log.grams = grams
        log.price = price
    }

    /// The whole scan taken back: its lines leave the stock and the spending, as if it had never been added.
    static func remove(_ ticket: ReceiptTicket, foods: [UUID: Ingredient], in context: ModelContext) {
        for log in ticket.purchases {
            removeStock(of: log, food: foods[log.ingredientID])
            context.delete(log)
        }
        ticket.extras.forEach(context.delete)
    }

    /// A plan line removed from a ticket: what it added to the stock leaves it.
    static func removeStock(of log: PurchaseLog, food: Ingredient?) {
        food?.stockGrams = max(0, (food?.stockGrams ?? 0) - log.grams)
    }
}
