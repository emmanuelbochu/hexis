import Foundation
import SwiftData
import UIKit

/// Turns receipt photos into matches with one small Gemini call (short prompt, compact JSON back).
enum ReceiptParser {
    private static let system = """
    Tu lis un ticket de caisse français (photo ou texte). Associe chaque ligne à un aliment de la liste (i = son index). \
    g = grammes totaux achetés (convertis kg, L≈kg, nombre d'unités × poids d'une unité u), p = prix total de la ligne en euros. \
    t = la ligne telle qu'imprimée sur le ticket, n = nombre d'unités achetées sur cette ligne (la quantité imprimée, 1 si rien). Ignore ce qui n'est pas dans la liste. uN = poids d'une unité, pN = poids du paquet habituel : si le poids n'est pas imprimé, g = quantité achetée × N. \
    Pour un aliment avec uN, g = nombre d'unités × N, jamais le poids imprimé (le poids brut d'une boîte n'est pas son poids égoutté) ; avec pN en plus, une ligne = un paquet = pN/uN unités. Un seul résultat par aliment. \
    « ou X » après un aliment = X est un équivalent accepté, à compter comme cet aliment. Ne confonds jamais deux aliments proches sinon (maquereau et thon, par exemple) : si la ligne ne permet pas de trancher (une marque seule), ignore-la. \
    Les corrections de l'utilisateur sont prioritaires. \
    x = les autres lignes d'aliments ou de boissons du ticket, hors liste (t = libellé lisible, p = prix de la ligne en euros, \
    c = Fruits, Frais, Épicerie, Boisson, Snack ou Autre) ; sans les remises, sacs, consignes ni totaux. \
    T = le total réellement payé du ticket en euros (à payer, remises déduites).
    """

    private static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "m": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": ["i": ["type": "INTEGER"], "g": ["type": "NUMBER"], "p": ["type": "NUMBER"], "n": ["type": "INTEGER"], "t": ["type": "STRING"]],
                    "required": ["i", "g", "p", "t", "n"],
                ],
            ],
            "x": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": ["t": ["type": "STRING"], "p": ["type": "NUMBER"], "c": ["type": "STRING"]],
                    "required": ["t", "p", "c"],
                ],
            ],
            "T": ["type": "NUMBER"],
        ],
        "required": ["m", "x"],
    ]

    /// Long side in pixels: enough to read small print, small enough to stay cheap.
    private static let maxSide: CGFloat = 1600

    static func jpeg(_ image: UIImage) -> Data? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.7) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// The photo goes to Gemini; if it does not answer in time, the text read on the phone is sent instead.
    static func matches(photos: [UIImage], foods: [Ingredient], aliases: [ReceiptAlias] = [], memories: [ProductMemory] = [], offPlan: [OffPlanProduct] = []) async throws -> (matches: [ReceiptMatch], extras: [ReceiptExtra], usedPhoto: Bool) {
        let prompt = ReceiptResolver.prompt(foods: foods, aliases: aliases, memories: memories)
        let data: Data
        var usedPhoto = true
        do {
            data = try await GeminiClient.generateJSON(system: system, prompt: prompt, schema: schema, images: photos.compactMap(jpeg), maxOutputTokens: 3000, timeout: 75)
        } catch GeminiClient.GeminiError.missingKey {
            throw GeminiClient.GeminiError.missingKey
        } catch {
            usedPhoto = false
            let text = await ReceiptOCR.text(from: photos)
            guard !text.isEmpty else { throw error }
            data = try await GeminiClient.generateJSON(system: system, prompt: prompt + "\n\nTicket :\n" + text, schema: schema, maxOutputTokens: 3000, timeout: 45)
        }
        let result = try ReceiptResolver.resolve(data, foods: foods, aliases: aliases, memories: memories, offPlan: offPlan)
        return (result.matches, result.extras, usedPhoto)
    }

    /// Keeps the off-plan lines so the weekly spending is complete.
    static func save(_ extras: [ReceiptExtra], in context: ModelContext) {
        extras.forEach { context.insert(ExtraPurchase(label: $0.label, category: $0.category, price: $0.price)) }
    }

    /// Remembers the lines the user moved to another food or out of the plan (one alias per printed line, the latest choice wins).
    /// A nil food means « not in the plan »: the line goes to the spending from then on.
    static func learn(_ corrections: [(label: String, food: Ingredient?)], known: [ReceiptAlias], in context: ModelContext) {
        for correction in corrections {
            let key = ReceiptLabel.normalize(correction.label)
            guard !key.isEmpty else { continue }
            known.filter { ReceiptLabel.normalize($0.label) == key }.forEach(context.delete)
            context.insert(ReceiptAlias(label: key, ingredientID: correction.food?.id ?? ReceiptResolver.offPlan))
        }
    }

    /// Adds the purchase to the stock, logs it, and refreshes the known price.
    static func apply(_ matches: [ReceiptMatch], in context: ModelContext) {
        ProductMemoryBook.learn(matches, in: context)
        for match in matches {
            let food = match.food
            food.stockGrams += match.grams
            if !ProductMemoryBook.learnPack(from: match, in: context), food.packGrams > 0, food.pieceGrams <= 0,
               !ProductMemoryBook.isLocked(food.id, in: context), let size = usualPack(of: food.id, adding: match.grams, in: context) { food.packGrams = size }
            context.insert(PurchaseLog(ingredientID: food.id, grams: match.grams, price: match.price))
            guard match.price > 0, let unit = usualUnitPrice(of: food.id, in: context) else { continue }
            food.packPrice = food.packGrams > 0 ? unit * food.packGrams / 1000 : unit
        }
    }

    /// The pack size the recent receipts (last 180 days, at most 12) say, counting the purchase being added.
    static func usualPack(of id: UUID, adding grams: Double, in context: ModelContext) -> Double? {
        var descriptor = FetchDescriptor<PurchaseLog>(predicate: #Predicate { $0.ingredientID == id }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 12
        let since = Calendar.current.date(byAdding: .day, value: -180, to: .now) ?? .distantPast
        let recent = ((try? context.fetch(descriptor)) ?? []).filter { $0.date >= since }.map(\.grams)
        return UsualPack.size(from: recent + [grams])
    }

    /// The usual price per kg: what the recent purchases (last 120 days, at most 8) really cost per kilo, weighted by quantity,
    /// so the brand bought most often counts most and one promotion or one small splurge barely moves it.
    static func usualUnitPrice(of id: UUID, in context: ModelContext) -> Double? {
        var descriptor = FetchDescriptor<PurchaseLog>(predicate: #Predicate { $0.ingredientID == id }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 8
        let since = Calendar.current.date(byAdding: .day, value: -120, to: .now) ?? .distantPast
        let recent = ((try? context.fetch(descriptor)) ?? []).filter { $0.price > 0 && $0.grams > 0 && $0.date >= since }
        let grams = recent.reduce(0) { $0 + $1.grams }
        return grams > 0 ? recent.reduce(0) { $0 + $1.price } / grams * 1000 : nil
    }
}
