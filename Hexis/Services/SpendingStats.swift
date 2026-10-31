import Foundation

/// What the scanned receipts say over time: the last weeks (plan foods and the rest), the usual week and day, and the foods
/// whose price per kilo moved. Only real tickets feed it.
struct SpendingStats {
    struct Week: Identifiable, Equatable {
        var start: Date
        var plan: Double
        var extra: Double
        var id: Date { start }
        var total: Double { plan + extra }
    }

    struct Mover: Identifiable, Equatable {
        var name: String
        var emoji: String
        /// Price per kilo now, and its change against the earlier purchases (0.12 = +12 %).
        var latest: Double
        var change: Double
        var id: String { name }
    }

    static let weekCount = 8
    /// A price per kilo that moved less than this is noise.
    static let meaningfulMove = 0.10
    static let minPurchases = 3

    struct Share: Identifiable, Equatable {
        var name: String
        var total: Double
        var id: String { name }
    }

    struct ProteinCost: Identifiable, Equatable {
        var name: String
        var emoji: String
        /// Euros for 100 g of protein, from the food's usual price.
        var euros: Double
        var id: String { name }
    }

    static let windowDays = 28
    /// A food whose protein gives less than this share of its calories is no protein source (oil, fruit, but also pasta,
    /// oats, bread, rice: 8–13 g per 100 g, still carbs). Chicken ~75 %, eggs ~35 %, cottage cheese ~40 %, pasta ~15 %.
    static let proteinSource = 0.25

    var weeks: [Week]
    var tickets: Int
    /// Where the last 4 weeks went, plan categories and the rest, biggest first.
    var shares: [Share]
    /// The 3 cheapest protein sources with a known price.
    var proteinCosts: [ProteinCost]
    /// Mean of the past weeks that have a ticket; nil before the first one is over.
    var weeklyAverage: Double?
    var movers: [Mover]

    var dailyAverage: Double? { weeklyAverage.map { $0 / 7 } }
    var thisWeek: Week? { weeks.last }
    /// This week against the usual one (0.1 = 10 % above); nil until a past week exists.
    var versusUsual: Double? { weeklyAverage.flatMap { $0 > 0 ? ((thisWeek?.total ?? 0) - $0) / $0 : nil } }
    var isEmpty: Bool { weeks.allSatisfy { $0.total == 0 } }

    init(purchases: [PurchaseLog], extras: [ExtraPurchase], foods: [Ingredient], now: Date = .now) {
        let thisStart = WeekReview.weekStart(containing: now)
        weeks = (-(Self.weekCount - 1)...0).map { offset in
            let start = WeekReview.weekStart(containing: thisStart, offset: offset)
            let end = WeekReview.weekStart(containing: thisStart, offset: offset + 1)
            return Week(
                start: start,
                plan: purchases.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.price },
                extra: extras.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.price }
            )
        }
        tickets = ReceiptHistory.tickets(purchases: purchases.filter { $0.date >= thisStart }, extras: extras.filter { $0.date >= thisStart }).count
        let since = now.addingTimeInterval(-Double(Self.windowDays) * 86_400)
        let category = Dictionary(foods.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first })
        var byCategory: [String: Double] = [:]
        for log in purchases where log.date >= since { byCategory[category[log.ingredientID] ?? "Autre", default: 0] += log.price }
        for extra in extras where extra.date >= since { byCategory[extra.category, default: 0] += extra.price }
        shares = byCategory.filter { $0.value > 0 }.map { Share(name: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
        proteinCosts = foods.compactMap { food -> ProteinCost? in
            guard food.packPrice > 0, food.kcal > 0, food.protein * 4 / food.kcal >= Self.proteinSource else { return nil }
            let per100 = food.packGrams > 0 ? food.packPrice / food.packGrams * 100 : food.packPrice / 10
            return ProteinCost(name: food.name, emoji: food.emoji, euros: per100 / food.protein * 100)
        }
        .sorted { $0.euros < $1.euros }.prefix(3).map { $0 }
        let past = weeks.dropLast().map(\.total).filter { $0 > 0 }
        weeklyAverage = past.isEmpty ? nil : past.reduce(0, +) / Double(past.count)
        movers = Self.movers(purchases: purchases, foods: foods, now: now)
    }

    private static func movers(purchases: [PurchaseLog], foods: [Ingredient], now: Date) -> [Mover] {
        let since = now.addingTimeInterval(-180 * 86_400)
        let byFood = Dictionary(grouping: purchases.filter { $0.price > 0 && $0.grams > 0 && $0.date >= since }, by: \.ingredientID)
        let names = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return byFood.compactMap { id, logs -> Mover? in
            let sorted = logs.sorted { $0.date < $1.date }
            guard sorted.count >= minPurchases, let food = names[id], let last = sorted.last else { return nil }
            let before = sorted.dropLast()
            let earlier = before.reduce(0) { $0 + $1.price } / before.reduce(0) { $0 + $1.grams } * 1000
            let latest = last.price / last.grams * 1000
            let change = (latest - earlier) / earlier
            return abs(change) >= meaningfulMove ? Mover(name: food.name, emoji: food.emoji, latest: latest, change: change) : nil
        }
        .sorted { abs($0.change) > abs($1.change) }
        .prefix(3).map { $0 }
    }
}
