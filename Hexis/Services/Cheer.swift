import Foundation
import SwiftData

/// A word of encouragement at the right moment, never the same twice. The fact is chosen here (`CheerFacts`), the AI only words it:
/// ~150 tokens in, ~25 out, once per fact, with a register picked locally so that no history has to be sent.
enum Cheer {
    /// Registers rotated so that two lines never sound alike; the last ones used are skipped. Hers: warm and light, never a coach who pushes.
    static let angles = Edition.isElle ? [
        "sobre et factuel", "humour léger", "calme et posé", "énergie joyeuse", "petit défi tendre",
        "fierté douce", "image drôle et courte", "complice", "mini-célébration", "poétique et bref",
    ] : [
        "sobre et factuel", "taquin, humour sec", "calme et posé", "plein d'énergie", "un défi pour la prochaine fois",
        "fier, comme un pote de salle", "image sportive courte", "complice", "entraîneur exigeant mais juste", "poétique et bref",
    ]

    /// Who reads it, and how adjectives agree (his app: none at all, to stay safe; hers: in the feminine).
    private static let audience = Edition.isElle
        ? "une femme qui s'entraîne sans être passionnée de salle (ton chaleureux et doux, jamais un mot sur son corps, sa silhouette ni son poids). Accorde au féminin"
        : "un pratiquant de musculation. Aucun adjectif ni participe accordé au genre (pas « prêt », « fier », « venu »)"

    private static let system = """
    Tu écris UNE phrase d'encouragement en français, en tutoyant, pour \(audience). Maximum 14 mots. \
    Appuie-toi sur un chiffre ou un nom du fait donné, n'invente rien d'autre. Respecte le registre demandé. \
    Pas d'emoji, pas de question, pas de « bravo » seul, jamais le mot « dur », aucun conseil médical ou diététique.
    """

    private static let schema: [String: Any] = ["type": "OBJECT", "properties": ["m": ["type": "STRING"]], "required": ["m"]]

    // MARK: Pure rules

    /// Lower case, no accents, no punctuation: two lines that differ only by that are the same line.
    static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "fr"))
        return folded.split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    /// Same line, or nearly (7 words in 10 in common).
    static func isTooClose(_ text: String, used: [String]) -> Bool {
        let words = Set(normalized(text).split(separator: " "))
        guard !words.isEmpty else { return true }
        return used.contains { other in
            let theirs = Set(normalized(other).split(separator: " "))
            guard !theirs.isEmpty else { return false }
            return Double(words.intersection(theirs).count) / Double(words.union(theirs).count) >= 0.7
        }
    }

    /// A register not used among the last ones (all but 3 of them are skipped).
    static func angle(avoiding recent: [String], choose: ([String]) -> String? = { $0.randomElement() }) -> String {
        let skipped = Set(recent.prefix(angles.count - 3))
        let free = angles.filter { !skipped.contains($0) }
        return choose(free) ?? angles[0]
    }

    /// One line cleaned for display: one sentence, no quotes, nothing too long.
    static func cleaned(_ raw: String) -> String? {
        let text = raw.components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"«» ").union(.whitespacesAndNewlines))
        return text.isEmpty || text.count > 140 ? nil : text
    }

    /// The line to show: the AI's (a new register on a second try if it repeats itself), else a hand-written one, else nothing.
    /// `generate` returns nil when the AI is out of reach: no second try then.
    static func resolve(
        fact: CheerFact, used: [String], recentAngles: [String], generate: (_ angle: String) async -> String?,
        choose: ([String]) -> String? = { $0.randomElement() }
    ) async -> (text: String, angle: String?)? {
        var tried = recentAngles
        for _ in 0..<2 {
            let angle = angle(avoiding: tried, choose: choose)
            tried.insert(angle, at: 0)
            guard let raw = await generate(angle) else { break }
            if let text = cleaned(raw), !isTooClose(text, used: used) { return (text, angle) }
        }
        return CheerPool.line(for: fact, used: used).map { ($0, nil) }
    }

    // MARK: Storage and AI

    /// What was said (newest first) and the registers used (newest first); a restore from a backup starts them over.
    private static func history(_ context: ModelContext) -> (said: [AIInsight], angles: [String]) {
        let all = (try? context.fetch(FetchDescriptor<AIInsight>(predicate: #Predicate { $0.kind == "cheer" || $0.kind == "cheerangle" }))) ?? []
        let sorted = all.sorted { $0.createdAt > $1.createdAt }
        return (sorted.filter { $0.kind == "cheer" }, sorted.filter { $0.kind == "cheerangle" }.map(\.text))
    }

    /// The line for a fact; asked once (`reuse` gives the same line back if the fact was worded already).
    @MainActor static func line(for fact: CheerFact, in context: ModelContext, reuse: Bool = true) async -> String? {
        let past = history(context)
        if let hit = past.said.first(where: { $0.key == fact.key }) { return reuse ? hit.text : nil }
        let result = await resolve(fact: fact, used: past.said.map(\.text), recentAngles: past.angles) { angle in
            await ask(fact: fact, angle: angle)
        }
        guard let result else { return nil }
        context.insert(AIInsight(kind: "cheer", key: fact.key, text: result.text))
        if let angle = result.angle { context.insert(AIInsight(kind: "cheerangle", key: fact.key, text: angle)) }
        context.saveReportingFailure()
        return result.text
    }

    private static func ask(fact: CheerFact, angle: String) async -> String? {
        guard GeminiClient.apiKey != nil else { return nil }
        struct Answer: Decodable { var m: String }
        let data = try? await GeminiClient.generateJSON(
            system: system, prompt: "Fait : \(fact.facts)\nRegistre : \(angle)", schema: schema, maxOutputTokens: 80, timeout: 8,
            temperature: 1, patient: false
        )
        return data.flatMap { try? JSONDecoder().decode(Answer.self, from: $0).m }
    }

    /// After a session, always: the fact of the session worded once.
    @MainActor static func afterSession(_ session: WorkoutSession, review: SessionReview, in context: ModelContext, now: Date = .now) async -> String? {
        let (dates, target) = sessionContext(excluding: session.id, in: context)
        let fact = CheerFacts.afterSession(
            sessionID: session.id, sessionDates: dates + [session.startedAt], weeklyTarget: target,
            records: review.records, volumeDelta: review.volumeDelta, now: now
        )
        return await line(for: fact, in: context)
    }

    /// On Home, at most one line a day and only when a fact deserves it; the answer (even « nothing ») is kept for the day.
    /// Silent once a session was done today: the end screen already spoke, and a morning « back after 8 days » would be stale.
    @MainActor static func home(in context: ModelContext, now: Date = .now) async -> String? {
        let day = CheerFacts.isoDay(now)
        let (dates, target) = sessionContext(excluding: nil, in: context)
        guard !dates.contains(where: { WeekReview.calendar.isDate($0, inSameDayAs: now) }) else { return nil }
        let marked = (try? context.fetch(FetchDescriptor<AIInsight>(predicate: #Predicate { $0.kind == "cheerday" }))) ?? []
        if let today = marked.first(where: { $0.key == day }) { return today.text.isEmpty ? nil : today.text }
        var fact = CheerFacts.onHome(sessionDates: dates, weeklyTarget: target, journey: nil, now: now)
        if fact == nil, let journey = await Journey.load(in: context, now: now) {
            fact = CheerFacts.onHome(sessionDates: dates, weeklyTarget: target, journey: journey, now: now)
        }
        var text: String?
        if let fact { text = await line(for: fact, in: context, reuse: false) }
        context.insert(AIInsight(kind: "cheerday", key: day, text: text ?? ""))
        context.saveReportingFailure()
        return text
    }

    private static func sessionContext(excluding id: UUID?, in context: ModelContext) -> (dates: [Date], target: Int) {
        let finished = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? []
        let program = (try? context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive })))?.first
        return (finished.filter { $0.id != id }.map(\.startedAt), program.map { ProgramCatalog.usualWeek($0.templates).count } ?? (Edition.isElle ? 2 : 4))
    }
}
