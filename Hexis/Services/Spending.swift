import Foundation

/// Food spending per week from the scanned receipts: plan foods and the rest, against the recent average.
struct Spending: Equatable {
    var thisWeek: Double
    var offPlan: Double
    /// Mean of the 4 weeks before, nil until one of them has a receipt.
    var average: Double?

    init?(purchases: [PurchaseLog], extras: [ExtraPurchase], now: Date = .now) {
        let thisStart = WeekReview.weekStart(containing: now)
        func total(_ offset: Int) -> (all: Double, extra: Double) {
            let start = WeekReview.weekStart(containing: thisStart, offset: offset)
            let end = WeekReview.weekStart(containing: thisStart, offset: offset + 1)
            let plan = purchases.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.price }
            let extra = extras.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.price }
            return (plan + extra, extra)
        }
        let current = total(0)
        let before = (-4 ... -1).map { total($0).all }.filter { $0 > 0 }
        guard current.all > 0 || !before.isEmpty else { return nil }
        thisWeek = current.all
        offPlan = current.extra
        average = before.isEmpty ? nil : before.reduce(0, +) / Double(before.count)
    }
}
