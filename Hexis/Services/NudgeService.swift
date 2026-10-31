import Foundation
import SwiftData

/// Hexis Elle: the lines of her notifications, planned ahead (`NudgePlan`) and worded by the AI (no canned lines); `NotificationHub` schedules them.
/// The phone can only fire what was scheduled: the plan reaches ~6 weeks into an absence, so the app does not have to be opened.
/// A slot already worded keeps its line: the AI is asked only for the new slots (after a session, or a fact that changed), in one request.
enum NudgeService {
    /// What is scheduled: slot key (`key(_:)`) → its line.
    private static let plannedKey = "nudgePlanned"
    private static let sentKey = "nudgeTexts"
    /// Lines already sent shown to the AI so that it does not repeat them (the local check `Cheer.isTooClose` covers all 60 kept).
    static let recentShown = 15
    @MainActor private static var refreshing = false

    private static let system = """
    Tu écris des notifications en français pour une femme qui s'entraîne 2 fois par semaine sans être passionnée de salle : \
    le but est qu'elle y aille, sans jamais la saouler. Tutoie-la, ton adulte, posé, avec de l'esprit mais jamais mièvre. \
    Appuie-toi sur ce qui marche vraiment : une intention précise (« ton jour habituel », « ce soir »), un geste minuscule \
    (« une séance courte suffit », « juste commencer »), le libre choix (« si ça te dit »), un fait réel du contexte donné. \
    Interdits : reproche, culpabilité, « enfin », « encore », « paresse », pression, comparaison, corps, silhouette, poids, \
    calories, régime. 14 mots maximum, une seule phrase, au plus un emoji. Chaque message suit le levier demandé et ne \
    ressemble à aucun autre. N'invente aucun chiffre ni nom d'exercice : appuie-toi seulement sur la situation donnée. \
    Écris comme un SMS d'une amie qui te connaît bien : simple, concret, naturel. Jamais de formule de développement personnel \
    (« savoure », « prends ce moment pour toi », « fierté », « ton effort », « ton énergie »). Ne félicite jamais une séance \
    qui n'a pas eu lieu.
    """

    /// Words that sound like a coaching card, or praise for an effort that may not exist: a line with one is dropped.
    static let banned = ["savour", "fierte", "fier ", "ton effort", "tes efforts", "pour toi", "bravo", "felicit"]

    /// Levers handed out one per message so that two never sound alike; each one is a known way to get someone moving.
    static let angles = [
        "intention précise : un moment ou un jour concret", "geste minuscule : une séance courte suffit, juste commencer",
        "libre choix : elle décide, aucune obligation", "humour sec et complice", "nouveau départ : une page qui se tourne (semaine, lundi)",
        "simple question ouverte, sans pression", "image drôle et courte", "clin d'œil complice sur le fait de ne pas avoir envie",
    ]

    private static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": ["messages": ["type": "ARRAY", "items": ["type": "STRING"]]],
        "required": ["messages"],
    ]

    // MARK: Pure rules

    /// A slot's identity: its notification (kind and moment) and the facts it was worded from.
    static func key(_ slot: NudgePlan.Slot) -> String { "\(identifier(slot))|\(slot.facts)" }
    static func identifier(_ slot: NudgePlan.Slot) -> String { "\(NotificationPolicy.prefix)\(slot.kind.rawValue).\(Int(slot.date.timeIntervalSince1970))" }

    /// The slots whose line is already planned (same moment, same facts) keep it; the others need the AI.
    static func reuse(slots: [NudgePlan.Slot], planned: [String: String]) -> (kept: [(slot: NudgePlan.Slot, text: String)], missing: [NudgePlan.Slot]) {
        var kept: [(slot: NudgePlan.Slot, text: String)] = []
        var missing: [NudgePlan.Slot] = []
        for slot in slots {
            if let text = planned[key(slot)] { kept.append((slot, text)) } else { missing.append(slot) }
        }
        return (kept, missing)
    }

    /// One line per slot: the AI's when it is clean and new; a slot without a clean new line is dropped (never a canned line).
    static func texts(for slots: [NudgePlan.Slot], generated: [String], recent: [String]) -> [(slot: NudgePlan.Slot, text: String)] {
        var used = recent
        var out: [(NudgePlan.Slot, String)] = []
        for (index, slot) in slots.enumerated() where index < generated.count {
            guard let text = Cheer.cleaned(generated[index]), !Cheer.isTooClose(text, used: used),
                  !banned.contains(where: { Cheer.normalized(text).contains($0) || Cheer.normalized(text + " ").contains($0) }) else { continue }
            used.insert(text, at: 0)
            out.append((slot, text))
        }
        return out
    }

    // MARK: Words

    /// Her notices from the plan: lines already worded are kept, the AI is asked once for the new moments only.
    /// `pending` are the identifiers still waiting in the phone (a restore or a reinstall loses them, and their lines with them).
    @MainActor static func notices(in context: ModelContext, now: Date = .now, pending: Set<String>, defaults: UserDefaults = .standard) async -> [Notice] {
        let finished = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? []
        let program = (try? context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive })))?.first
        let target = program.map { ProgramCatalog.usualWeek($0.templates).count } ?? 2
        let slots = NudgePlan.slots(sessionDates: finished.map(\.startedAt), weeklyTarget: target, now: now)

        let planned = (defaults.dictionary(forKey: plannedKey) as? [String: String] ?? [:]).filter { pending.contains(String($0.key.prefix { $0 != "|" })) }
        let reused = reuse(slots: slots, planned: planned)
        var kept = reused.kept
        let recent = defaults.stringArray(forKey: sentKey) ?? []
        if !reused.missing.isEmpty, let generated = await ask(slots: reused.missing, avoiding: Array(recent.prefix(recentShown))) {
            let worded = texts(for: reused.missing, generated: generated, recent: recent)
            kept += worded
            defaults.set(Array((worded.map(\.text) + recent).prefix(60)), forKey: sentKey)
        }
        defaults.set(Dictionary(kept.map { (key($0.slot), $0.text) }, uniquingKeysWith: { a, _ in a }), forKey: plannedKey)
        return kept.map { Notice(kind: $0.slot.kind == .weekAtRisk ? .weekAtRisk : .absence, date: $0.slot.date, title: "Hexis", body: $0.text) }
    }

    /// All the lines in one request (~400 tokens); nil when the AI is out of reach.
    private static func ask(slots: [NudgePlan.Slot], avoiding recent: [String]) async -> [String]? {
        guard !slots.isEmpty, GeminiClient.apiKey != nil else { return nil }
        struct Answer: Decodable { var messages: [String] }
        let registers = angles.shuffled()
        let situations = slots.enumerated().map { "\($0.offset + 1). [levier : \(registers[$0.offset % registers.count])] \(label($0.element))" }.joined(separator: "\n")
        var prompt = "Écris exactement \(slots.count) notifications, une par situation, dans l'ordre :\n\(situations)"
        if !recent.isEmpty { prompt += "\nDéjà envoyées, à ne pas répéter :\n" + recent.map { "- \($0)" }.joined(separator: "\n") }
        let data = try? await GeminiClient.generateJSON(
            system: system, prompt: prompt, schema: schema, maxOutputTokens: 900, timeout: 15, temperature: 1, patient: true
        )
        return data.flatMap { try? JSONDecoder().decode(Answer.self, from: $0).messages }
    }

    private static func label(_ slot: NudgePlan.Slot) -> String {
        switch slot.kind {
        case .absence: "Elle n'est pas venue depuis un moment (aucun effort récent à saluer). \(slot.facts) Invite-la simplement à venir, sans pression."
        case .weekAtRisk: "Sa semaine n'est pas finie. \(slot.facts) Donne-lui envie d'en faire une de plus."
        }
    }
}
