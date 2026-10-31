import Foundation

/// A receipt line to review: matched food, why it looks odd (if it does) and whether it will be applied.
struct ReceiptReviewLine: Identifiable {
    enum Warning: Equatable {
        case quantity, price, duplicate, missingPrice

        var text: String {
            switch self {
            case .quantity: "Quantité très élevée, à vérifier"
            case .price: "Prix inhabituel, à vérifier"
            case .duplicate: "Déjà ajouté (même ticket ?)"
            case .missingPrice: "Prix non lu"
            }
        }
    }

    var match: ReceiptMatch
    /// The line as the AI read it, to show what the user changed.
    var original: ReceiptMatch
    /// The food the AI chose, to spot a correction.
    var originalFoodID: UUID
    var warning: Warning?
    var isSelected: Bool
    /// Printed labels merged into this line by a correction.
    var corrections: [String] = []

    var id: UUID { match.id }

    /// Quantity, weight or price differ from the AI's reading.
    var isChanged: Bool {
        abs(match.grams - original.grams) > 0.5 || abs(match.price - original.price) > 0.005 || match.units != original.units
    }
}

/// Sanity checks on what the AI read: odd lines are shown unticked so nothing wrong reaches the stock by mistake.
enum ReceiptGuard {
    static func review(
        _ matches: [ReceiptMatch], weeklyNeeds: [UUID: Double], recent: [PurchaseLog], now: Date = .now
    ) -> [ReceiptReviewLine] {
        let repeated = earlierScan(of: matches, recent: recent, now: now).map(\.lines) ?? []
        return matches.map { match in
            let warning = repeated.contains(match.food.id) ? .duplicate
                : warning(for: match, need: weeklyNeeds[match.food.id] ?? 0, recent: recent, now: now)
            // A missing price is harmless for the stock, so it stays ticked.
            return ReceiptReviewLine(match: match, original: match, originalFoodID: match.food.id, warning: warning, isSelected: warning == nil || warning == .missingPrice)
        }
    }

    /// The same ticket read again: a past scan (lines logged within 5 minutes, last 30 days) holding most of these lines
    /// with the same price and quantity. Returns its date and the foods found in it.
    static func earlierScan(of matches: [ReceiptMatch], recent: [PurchaseLog], now: Date = .now) -> (date: Date, lines: Set<UUID>)? {
        let since = now.addingTimeInterval(-30 * 86_400)
        var scans: [[PurchaseLog]] = []
        for log in recent.filter({ $0.date >= since }).sorted(by: { $0.date < $1.date }) {
            if let last = scans.last?.last, log.date.timeIntervalSince(last.date) < 300 { scans[scans.count - 1].append(log) } else { scans.append([log]) }
        }
        let priced = matches.filter { $0.grams > 0 }
        guard priced.count >= 2 else { return nil }
        for scan in scans.reversed() {
            let same = Set(priced.filter { match in
                scan.contains { $0.ingredientID == match.food.id && abs($0.price - match.price) <= 0.02 && abs($0.grams - match.grams) <= match.grams * 0.02 }
            }.map(\.food.id))
            if same.count >= max(2, Int((Double(priced.count) * 0.6).rounded(.up))), let date = scan.first?.date { return (date, same) }
        }
        return nil
    }

    static func warning(for match: ReceiptMatch, need: Double, recent: [PurchaseLog], now: Date) -> ReceiptReviewLine.Warning? {
        let food = match.food
        let limit = min(max(need * 4, food.packGrams * 3, 2000), 20000)
        if match.grams > limit { return .quantity }
        let day: TimeInterval = 24 * 3600
        if recent.contains(where: {
            $0.ingredientID == food.id && now.timeIntervalSince($0.date) < day
                && abs($0.grams - match.grams) <= match.grams * 0.01
        }) { return .duplicate }
        guard match.price > 0 else { return .missingPrice }
        // Only compared with what was really paid before (2 tickets at least): a price typed or guessed is not a history.
        let paid = recent.filter { $0.ingredientID == food.id && $0.price > 0 && $0.grams > 0 }
        guard paid.count >= 2 else { return nil }
        let known = paid.reduce(0) { $0 + $1.price } / paid.reduce(0) { $0 + $1.grams } * 1000
        let unit = match.price / match.grams * 1000
        return unit > known * 2.5 || unit < known * 0.4 ? .price : nil
    }
}
