import Foundation
import SwiftData

/// This week's off-plan items: free text in, tidy lines out (emoji, short name, quantity). The AI tidies (~100 tokens);
/// without it, the text is split locally so nothing typed is lost.
enum ShoppingNotes {
    struct Item: Equatable, Decodable {
        var e: String
        var n: String
        var q: String
    }

    private static let system = """
    Transforme une liste de courses écrite librement en articles. Pour chaque chose à acheter : l'emoji le plus juste (un seul), \
    un nom court en français avec une majuscule, la quantité normalisée (« 2 », « 500 g », « 1 pack », « 1 L ») ou vide si \
    aucune n'est donnée. N'invente rien, n'ajoute rien, un article par chose, pas de doublon.
    """

    private static let schema: [String: Any] = [
        "type": "ARRAY",
        "items": [
            "type": "OBJECT", "properties": ["e": ["type": "STRING"], "n": ["type": "STRING"], "q": ["type": "STRING"]],
            "required": ["e", "n", "q"],
        ],
    ]

    /// The tidy items: the AI's, else the local split.
    static func tidy(_ text: String) async -> [Item] {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }
        if GeminiClient.apiKey != nil,
           let data = try? await GeminiClient.generateJSON(system: system, prompt: raw, schema: schema, maxOutputTokens: 600, timeout: 15, patient: false),
           let items = try? JSONDecoder().decode([Item].self, from: data) {
            let clean = items.compactMap(cleaned)
            if !clean.isEmpty { return clean }
        }
        return split(raw)
    }

    /// Local fallback: one item per line, comma (not a decimal one) or « et »; a leading number (and unit) becomes the
    /// quantity, and the « de » after it goes.
    static func split(_ text: String) -> [Item] {
        let parts = text.replacingOccurrences(of: " et ", with: ",")
            .replacingOccurrences(of: #"(?<!\d),|,(?!\d)"#, with: "\n", options: .regularExpression)
            .components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-•*[] ").union(.whitespaces)) }
            .filter { !$0.isEmpty }
        return parts.compactMap { part in
            var words = part.split(separator: " ").map(String.init)
            var quantity: [String] = []
            if let first = words.first, first.first?.isNumber == true {
                quantity.append(words.removeFirst())
                let units = ["g", "kg", "l", "ml", "cl", "pack", "packs", "boîte", "boîtes", "paquet", "paquets", "x"]
                if let unit = words.first, units.contains(unit.lowercased()) { quantity.append(words.removeFirst()) }
                if words.count > 1, ["de", "d'"].contains(words[0].lowercased()) { words.removeFirst() }
                if let word = words.first, let range = word.range(of: #"^[dD]['’]"#, options: .regularExpression), word.count > 2 {
                    words[0] = String(word[range.upperBound...])
                }
            }
            return cleaned(Item(e: "🛒", n: words.joined(separator: " "), q: quantity.joined(separator: " ")))
        }
    }

    private static func cleaned(_ item: Item) -> Item? {
        let name = item.n.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let emoji = item.e.trimmingCharacters(in: .whitespaces)
        return Item(e: emoji.isEmpty || emoji.count > 2 ? "🛒" : emoji, n: name.prefix(1).uppercased() + name.dropFirst(), q: item.q.trimmingCharacters(in: .whitespaces))
    }

    /// Adds the items to the current cycle, skipping a name already on it (or twice in what was typed).
    @MainActor static func add(_ items: [Item], cycle: Date, in context: ModelContext) {
        var existing = Set(current(cycle: cycle, in: context).map { $0.name.lowercased() })
        for item in items where existing.insert(item.n.lowercased()).inserted {
            context.insert(ShoppingNote(emoji: item.e, name: item.n, quantity: item.q, cycleStart: cycle))
        }
        context.saveReportingFailure()
    }

    @MainActor static func current(cycle: Date, in context: ModelContext) -> [ShoppingNote] {
        visible((try? context.fetch(FetchDescriptor<ShoppingNote>(sortBy: [SortDescriptor(\.createdAt)]))) ?? [], cycle: cycle)
    }

    /// The cycle's items plus those of earlier cycles not bought yet: typed on Thursday, still there for Saturday's shopping.
    static func visible(_ notes: [ShoppingNote], cycle: Date) -> [ShoppingNote] {
        notes.filter { Calendar.current.isDate($0.cycleStart, inSameDayAs: cycle) || ($0.cycleStart < cycle && !$0.checked) }
    }

    /// Ticks or unticks an item; one carried over from an earlier cycle joins this one, so it stays struck through until the next.
    static func toggle(_ note: ShoppingNote, cycle: Date) {
        note.checked.toggle()
        if note.cycleStart < cycle { note.cycleStart = cycle }
    }

    /// Items of past cycles that were bought: they go away.
    static func stale(_ notes: [ShoppingNote], cycle: Date) -> [ShoppingNote] {
        notes.filter { $0.checked && $0.cycleStart < cycle && !Calendar.current.isDate($0.cycleStart, inSameDayAs: cycle) }
    }

    @MainActor static func prune(before cycle: Date, in context: ModelContext) {
        let old = stale((try? context.fetch(FetchDescriptor<ShoppingNote>())) ?? [], cycle: cycle)
        guard !old.isEmpty else { return }
        old.forEach(context.delete)
        context.saveReportingFailure()
    }
}
