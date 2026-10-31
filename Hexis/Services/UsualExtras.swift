import Foundation

/// Off-plan foods bought again and again (seen on at least 3 different days): when one is due again by its own rhythm,
/// the list reminds it with its usual price, so nothing habitual is forgotten.
enum UsualExtras {
    struct Habit: Identifiable, Equatable {
        var label: String
        var price: Double
        var id: String { label }
    }

    static func due(_ purchases: [ExtraPurchase], now: Date = .now, calendar: Calendar = .current) -> [Habit] {
        let grouped = Dictionary(grouping: purchases) { ReceiptLabel.normalize($0.label) }
        return grouped.compactMap { key, items -> Habit? in
            let days = Set(items.map { calendar.startOfDay(for: $0.date) }).sorted()
            guard !key.isEmpty, days.count >= 3, let last = days.last else { return nil }
            let gaps = zip(days, days.dropFirst()).map { calendar.dateComponents([.day], from: $0, to: $1).day ?? 0 }.sorted()
            let rhythm = max(gaps[gaps.count / 2], 3)
            let since = calendar.dateComponents([.day], from: last, to: calendar.startOfDay(for: now)).day ?? 0
            // Due from 80 % of its rhythm, dropped once it has clearly stopped (4 rhythms without it).
            guard Double(since) >= 0.8 * Double(rhythm), since <= 4 * rhythm else { return nil }
            let prices = items.map(\.price).sorted()
            return Habit(label: items.sorted { $0.date > $1.date }[0].label, price: prices[prices.count / 2])
        }
        .sorted { $0.price > $1.price }
        .prefix(6).map { $0 }
    }
}
