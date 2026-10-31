import Foundation

/// Minimal Gemini REST call returning JSON. The key lives in `Secrets.plist` (never in Git).
enum GeminiClient {
    enum GeminiError: LocalizedError {
        case missingKey, http(Int), badResponse

        var errorDescription: String? {
            switch self {
            case .missingKey: "Clé Gemini absente (Secrets.plist)."
            case .http(let code) where isOverload(code): "Gemini est surchargé (\(code)), réessaie dans une minute."
            case .http(let code): "Gemini a répondu \(code)."
            case .badResponse: "Réponse Gemini illisible."
            }
        }
    }

    /// Answers that mean « busy, try again » (rate limit, server error, overload).
    static func isOverload(_ code: Int) -> Bool { [429, 500, 502, 503, 504].contains(code) }

    /// Waits (seconds) before each new attempt after an overload; a timeout is not retried (it already waited long enough).
    static let retryDelays: [Double] = [2, 6]

    /// One model for the whole app: reads photos (the Lite ones stall on images) and words short texts.
    static let model = "gemini-3.6-flash"

    static var apiKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let key = dict["GeminiAPIKey"] as? String, !key.isEmpty, key != "PASTE_KEY_HERE"
        else { return nil }
        return key
    }

    /// One request, answer forced to JSON matching `schema` (Gemini's OpenAPI subset).
    /// `temperature` 0 (the default) keeps readings repeatable; `patient: false` gives up at the first overload (a short text that can wait).
    static func generateJSON(
        system: String, prompt: String, schema: [String: Any], images: [Data] = [], maxOutputTokens: Int = 1024, timeout: TimeInterval = 40,
        temperature: Double = 0, patient: Bool = true
    ) async throws -> Data {
        var attempt = 0
        while true {
            do {
                return try await send(system: system, prompt: prompt, schema: schema, images: images, maxOutputTokens: maxOutputTokens, timeout: timeout, temperature: temperature)
            } catch GeminiError.http(let code) where patient && isOverload(code) && attempt < retryDelays.count {
                try await Task.sleep(for: .seconds(retryDelays[attempt]))
                attempt += 1
            } catch {
                Diagnostics.record(.geminiFailed, String(describing: error))
                throw error
            }
        }
    }

    private static func send(system: String, prompt: String, schema: [String: Any], images: [Data], maxOutputTokens: Int, timeout: TimeInterval, temperature: Double) async throws -> Data {
        guard let key = apiKey else { throw GeminiError.missingKey }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw GeminiError.badResponse
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var config: [String: Any] = [
            "responseMimeType": "application/json", "responseSchema": schema, "temperature": temperature, "maxOutputTokens": maxOutputTokens,
        ]
        // Reading a ticket or wording a few figures needs no long reasoning: it only costs time and tokens.
        config["thinkingConfig"] = ["thinkingLevel": "minimal"]
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["parts": images.map { ["inline_data": ["mime_type": "image/jpeg", "data": $0.base64EncodedString()]] } + [["text": prompt]]]],
            "generationConfig": config,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 { throw GeminiError.http(status) }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidate = (root["candidates"] as? [[String: Any]])?.first,
              let parts = (candidate["content"] as? [String: Any])?["parts"] as? [[String: Any]],
              // Thinking models may send a thought part first: the answer is the last non-thought text part.
              let text = parts.last(where: { $0["thought"] as? Bool != true && $0["text"] is String })?["text"] as? String,
              let json = text.data(using: .utf8)
        else { throw GeminiError.badResponse }
        return json
    }
}
