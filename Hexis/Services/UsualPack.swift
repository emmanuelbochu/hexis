import Foundation

/// Learns the pack a food is really bought in from the receipts: the smallest quantity ever bought, when the other
/// purchases are whole multiples of it (500 g, 1 000 g, 1 500 g of pasta ⇒ 500 g packs). A food always bought in the same
/// quantity says nothing (two packs or one big one?), so the usual size stays as it is.
enum UsualPack {
    private static let tolerance = 0.08

    static func size(from purchases: [Double]) -> Double? {
        let grams = purchases.filter { $0 >= 50 }.sorted()
        guard grams.count >= 3, let smallest = grams.first else { return nil }
        let counts = grams.map { $0 / smallest }
        let whole = counts.filter { abs($0 - $0.rounded()) <= tolerance * max($0.rounded(), 1) }
        guard Double(whole.count) >= 0.7 * Double(grams.count), Set(whole.map { $0.rounded() }).count >= 2 else { return nil }
        return (smallest / 10).rounded() * 10
    }
}
