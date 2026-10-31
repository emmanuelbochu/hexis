import Foundation

/// A receipt line matched to a food of the plan.
struct ReceiptMatch: Identifiable {
    var food: Ingredient
    var grams: Double
    var price: Double
    /// The line as printed on the ticket, kept to learn from corrections.
    var label = ""
    /// How many packs the ticket says were bought (nil when it does not say), to show « 3 × 650 g » instead of a lone total.
    var units: Int?

    var id: UUID { food.id }

    /// Grams of one pack when the ticket gave a count of two or more (not for foods sold by the piece, which show a count).
    var gramsPerUnit: Double? {
        guard food.pieceGrams <= 0, let units, units >= 2 else { return nil }
        return grams / Double(units)
    }

    /// Counts add up only when both are known.
    static func sum(_ a: Int?, _ b: Int?) -> Int? {
        guard let a, let b else { return nil }
        return a + b
    }

    /// Foods counted in pieces but sold in boxes (eggs by 6, 12 or 20): the unit of the ticket is the box.
    var soldInBoxes: Bool { food.pieceGrams > 0 && food.packGrams > food.pieceGrams * 1.5 }

    /// Units to show in the editor: the ticket's count, else one pack (a count of pieces for foods sold by the piece).
    var editableUnits: Int {
        if let units, units >= 1 { return units }
        guard food.pieceGrams > 0, !soldInBoxes else { return 1 }
        return max(1, Int((grams / food.pieceGrams).rounded()))
    }

    var editableUnitGrams: Double { grams / Double(editableUnits) }

    /// Retypes the count and the weight of one unit (a box, a jar, a piece): the total follows.
    mutating func set(units: Int, unitGrams: Double) {
        self.units = max(1, units)
        grams = Double(max(1, units)) * max(0, unitGrams)
    }

    /// « 3 × 650 g » or « 2 × 20 œufs » when the count is known, else the total (« 650 g », « 12 boîtes »).
    var quantityText: String {
        if soldInBoxes, let units, units >= 1 { return "\(units) × \(QuantityFormatter.text(grams: grams / Double(units), of: food))" }
        guard let each = gramsPerUnit else { return QuantityFormatter.text(grams: grams, of: food) }
        return "\(units ?? 0) × \(QuantityFormatter.weight((each / 5).rounded() * 5))"
    }
}

/// A food line of the ticket outside the plan, kept for the spending.
struct ReceiptExtra: Identifiable {
    var label: String
    var category: String
    var price: Double
    /// The line as printed (to remember what the user says it is), and whether he explained it.
    var printed = ""
    var edited = false
    var id = UUID()
}

/// The prompt sent with a receipt and the reading of Gemini's compact JSON answer, with what the user taught the app
/// (`ReceiptAlias`: a printed line is a food of the plan, or is not in the plan at all).
enum ReceiptResolver {
    /// Alias target meaning « this printed line is not in the plan » (a model already shipped, so no new field).
    static let offPlan = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    /// The line added so the spending matches the printed total (more, or less after discounts), and the gap under which it is not worth one.
    static let missingLabel = "Autres lignes du ticket"
    static let discountLabel = "Remises du ticket"
    static let missingPriceThreshold = 0.5

    private struct Answer: Decodable {
        var m: [Line]
        var x: [Extra]?
        /// What the ticket says was paid (after discounts).
        var T: Double?
    }

    private struct Extra: Decodable {
        var t: String
        var p: Double
        var c: String?
    }

    private struct Line: Decodable {
        var i: Int
        var g: Double
        var p: Double
        var t: String?
        /// Packs on the ticket line (the printed quantity).
        var n: Int?
    }

    /// Foods of the plan (`index|name`, `|uN` = one unit weighs N g, `|pN` = the usual pack weighs N g) then the corrections.
    static func prompt(foods: [Ingredient], aliases: [ReceiptAlias], memories: [ProductMemory] = []) -> String {
        let list = foods.enumerated().map { i, food in
            var line = "\(i)|\(food.name)"
            if food.pieceGrams > 0 { line += "|u\(Int(food.pieceGrams))" }
            if food.packGrams > 0, food.packGrams > food.pieceGrams { line += "|p\(Int(food.packGrams))" }
            if let other = FoodSubstitutes.alternative(for: food) { line += "|ou \(other)" }
            return line
        }.joined(separator: "\n")
        var prompt = "Aliments:\n\(list)"
        let learned = aliases.sorted { $0.createdAt > $1.createdAt }.prefix(40).compactMap { alias -> String? in
            if alias.ingredientID == offPlan { return "« \(alias.label) » = hors liste" }
            return foods.firstIndex { $0.id == alias.ingredientID }.map { "« \(alias.label) » = \($0)" }
        }
        if !learned.isEmpty { prompt += "\n\nCorrections de l'utilisateur :\n" + learned.joined(separator: "\n") }
        let known = ProductMemoryBook.promptLines(memories, foods: foods)
        if !known.isEmpty { prompt += "\n\nProduits déjà achetés (ligne = aliment · poids d'une unité · prix d'une unité TTC) :\n" + known.joined(separator: "\n") }
        return prompt
    }

    static func resolve(_ data: Data, foods: [Ingredient], aliases: [ReceiptAlias] = [], memories: [ProductMemory] = [], offPlan products: [OffPlanProduct] = []) throws -> (matches: [ReceiptMatch], extras: [ReceiptExtra]) {
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        let learned = Dictionary(aliases.map { (ReceiptLabel.normalize($0.label), $0.ingredientID) }, uniquingKeysWith: { _, latest in latest })
        var merged: [Int: ReceiptMatch] = [:]
        var extras: [ReceiptExtra] = []
        for line in answer.m where line.g > 0 {
            let taught = learned[ReceiptLabel.normalize(line.t ?? "")]
            if taught == offPlan {
                extras.append(ReceiptExtra(label: line.t ?? "", category: "Épicerie", price: max(0, line.p), printed: line.t ?? ""))
                continue
            }
            // A line the user already corrected keeps the food he chose, whatever the AI says now.
            let index = taught.flatMap { id in foods.firstIndex { $0.id == id } } ?? line.i
            guard foods.indices.contains(index) else { continue }
            var match = merged[index] ?? ReceiptMatch(food: foods[index], grams: 0, price: 0, label: line.t ?? "")
            match.grams += ProductMemoryBook.grams(line.g, units: line.n, label: line.t ?? "", food: foods[index], in: memories)
            match.price += max(0, line.p)
            // Two lines of one food add their counts; one line without a count makes the count unknown.
            match.units = merged[index] == nil ? line.n : ReceiptMatch.sum(match.units, line.n)
            merged[index] = match
        }
        extras += (answer.x ?? []).filter { $0.p > 0 && !$0.t.isEmpty }.prefix(80)
            .map { ReceiptExtra(label: $0.t, category: $0.c ?? "Autre", price: $0.p, printed: $0.t) }
        extras = OffPlanBook.named(extras, with: products)
        // Whatever the lines do not explain (a line read wrong, a food without a weight, a bag) is still money spent.
        let counted = merged.values.reduce(0) { $0 + $1.price } + extras.reduce(0) { $0 + $1.price }
        if let total = answer.T, abs(total - counted) >= missingPriceThreshold {
            let gap = total - counted
            extras.append(ReceiptExtra(label: gap > 0 ? missingLabel : discountLabel, category: "Autre", price: gap))
        }
        return (merged.keys.sorted().compactMap { merged[$0] }, extras)
    }
}
