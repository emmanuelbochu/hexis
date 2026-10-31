import Foundation

/// An off-plan line the user described in his own words: the AI puts it in shape (a clean name, a category) in ~60 tokens;
/// without it the words are kept as typed.
enum ExtraTidy {
    static let categories = ["Fruits", "Frais", "Épicerie", "Boisson", "Snack", "Maison", "Autre"]

    private struct Answer: Decodable {
        var n: String
        var c: String
    }

    private static let system = """
    Une ligne d'un ticket de caisse français est expliquée par son propriétaire. Donne un nom court et clair en français \
    (majuscule initiale, sans marque ni poids sauf si utile) et la catégorie : Fruits, Frais, Épicerie, Boisson, Snack, \
    Maison (produit non alimentaire) ou Autre. N'invente rien au-delà de l'explication.
    """

    private static let schema: [String: Any] = [
        "type": "OBJECT", "properties": ["n": ["type": "STRING"], "c": ["type": "STRING"]], "required": ["n", "c"],
    ]

    static func tidy(printed: String, said: String, current: String) async -> (name: String, category: String) {
        let text = said.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return (current, "Autre") }
        if GeminiClient.apiKey != nil,
           let data = try? await GeminiClient.generateJSON(
               system: system, prompt: "Ligne imprimée : \(printed)\nExplication : \(text)", schema: schema, maxOutputTokens: 120, timeout: 15, patient: false),
           let answer = try? JSONDecoder().decode(Answer.self, from: data), !answer.n.isEmpty {
            return (answer.n, categories.contains(answer.c) ? answer.c : "Autre")
        }
        return (fallback(text), "Autre")
    }

    /// The words as typed, first letter up.
    static func fallback(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
