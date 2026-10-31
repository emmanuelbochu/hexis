import Foundation
import SwiftData

/// On-demand reading of one exercise's history by Gemini: the numbers are computed here, the AI only explains them and picks the likely cause.
enum ProgressDiagnosis {
    private static let system = """
    Tu es un coach de musculation fondé sur les preuves (méta-analyses : Schoenfeld, Pelland 2024, Refalo 2023, Morton 2018). \
    Cadre : double progression au RPE, séries proches de l'échec (RIR 0-2), cycles de \(ProgramCatalog.trainingWeeks) semaines d'entraînement puis un déload (mêmes charges, \
    moitié des séries) ; l'app règle déjà seule charges, séries, fourchette de reps et repos, et la décision qu'elle a prise t'est donnée. \
    À partir des chiffres (e1RM par séance, RPE moyen, écart entre séances, ressenti, séries par semaine du muscle, poids de corps, \
    calories), dis en 2 phrases courtes ce qui se passe (progression, plateau, perte de force) et la cause la plus probable \
    (récupération, effort trop loin de l'échec, volume, calories en déficit, écart entre séances). Si la décision de l'app est donnée, \
    ne la contredis pas : explique pourquoi elle aide. Sinon, termine par une seule action concrète compatible avec ce cadre. \
    Appuie-toi uniquement sur les chiffres, n'invente rien, réponds « Pas assez de données. » si c'est le cas. Pas de politesse, pas de liste.\(reader)
    """

    /// Hexis Elle: she reads her effort as the reps she could still do, never RPE/RIR, and nothing about her body.
    private static let reader = Edition.isElle
        ? " Tu t'adresses à une femme qui ne connaît ni RPE ni RIR : parle de « reps qu'elle aurait encore pu faire » (RPE 9 = 1), tutoie-la, accorde au féminin, jamais un mot sur son corps ni son poids."
        : ""

    private static let schema: [String: Any] = [
        "type": "OBJECT", "properties": ["d": ["type": "STRING"]], "required": ["d"],
    ]

    /// Compact facts: the last 10 sessions of the exercise plus the context (body weight trend, intake).
    /// What the program aims for and what the app already decided for this exercise.
    struct Context {
        var plan = ""
        var weeklySets: Int?
        var decision: String?
    }

    static func facts(name: String, perfs: [SessionPerf], slope: BodyInsights.Slope?, context: Context = Context(), now: Date = .now) -> String {
        let recent = perfs.suffix(10)
        let calendar = Calendar.current
        var lines = ["Exercice : \(name). Séances (récentes en dernier) : "]
        var previous: Date?
        lines[0] += recent.map { perf in
            let gap = previous.map { calendar.dateComponents([.day], from: $0, to: perf.date).day ?? 0 }
            previous = perf.date
            var parts = ["e1RM \(Int(perf.e1RM.rounded())) kg"]
            if let rpe = perf.avgRPE { parts.append(String(format: "RPE %.1f", rpe)) }
            if let feeling = perf.feeling, feeling != .good { parts.append(feeling.title) }
            if let gap { parts.append("\(gap) j après la précédente") }
            return "[" + parts.joined(separator: ", ") + "]"
        }.joined(separator: " ")
        if let best = perfs.map(\.e1RM).max(), let bestIndex = perfs.lastIndex(where: { $0.e1RM >= best * 0.99 }) {
            lines.append("Meilleur e1RM \(Int(best.rounded())) kg, il y a \(perfs.count - 1 - bestIndex) séances.")
        }
        if !context.plan.isEmpty { lines.append("Programme : \(context.plan).") }
        if let sets = context.weeklySets { lines.append("Séries par semaine pour ce muscle : \(sets).") }
        if let decision = context.decision { lines.append("Décision de l'app : \(decision)") }
        if let slope {
            var body = String(format: "Poids de corps %+.1f kg/sem. sur %d pesées", slope.kgPerWeek, slope.weighIns)
            if let kcal = slope.kcalPerDay { body += ", \(kcal) kcal/j" }
            lines.append(body + ".")
        }
        return lines.joined(separator: "\n")
    }

    /// The newest reading of an exercise (keys start with the exercise id).
    static func latest(for exerciseID: UUID, in insights: [AIInsight]) -> String? {
        let prefix = exerciseID.uuidString + "#"
        return insights.filter { $0.kind == "progress" && $0.key.hasPrefix(prefix) }.max { $0.createdAt < $1.createdAt }?.text
    }

    /// After a session: reads the exercises that stalled or dropped (in this gym, deload weeks left out), once per new
    /// session count. Nothing to tap.
    @MainActor static func refresh(exerciseIDs: Set<UUID>, gymID: UUID?, context: ModelContext) async {
        let cached = (try? context.fetch(FetchDescriptor<AIInsight>(predicate: #Predicate { $0.kind == "progress" }))) ?? []
        let since = Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now
        let cycle = TrainingCycle.load(context: context)
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let rehab = Set(ProgramCatalog.rehabExercises.map { $0.name.lowercased() })
        let tweaks = (try? context.fetch(FetchDescriptor<ExerciseTweak>(predicate: #Predicate { $0.gymID == gymID }))) ?? []
        let program = (try? context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive })))?.first
        let items = program?.templates.flatMap { $0.blocks.flatMap(\.exercises) } ?? []
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var slope: BodyInsights.Slope?
        var asked = 0
        for id in exerciseIDs where asked < 3 {
            guard let exercise = byID[id], !rehab.contains(exercise.name.lowercased()),
                  (ProgramCatalog.exercise(named: exercise.name)?.unit ?? "").isEmpty else { continue }
            let sets = ((try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.exerciseID == id && $0.gymID == gymID }))) ?? [])
                .filter { !cycle.isDeload($0.completedAt) }
            let feelings = (try? context.fetch(FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { $0.exerciseID == id || $0.exerciseID == $0.sessionID }))) ?? []
            // A tired day proves nothing (the adjuster leaves it out too): it must not trigger a reading.
            let perfs = Performance.sessions(sets: sets, feelings: feelings).filter { $0.feeling != .tired }
            guard perfs.count >= 4, let last = perfs.last, needsReading(perfs, last: last, id: id) else { continue }
            let key = "\(id.uuidString)#\(gymID?.uuidString ?? "")#\(perfs.count)"
            guard !cached.contains(where: { $0.key == key }) else { continue }
            if slope == nil, Edition.usesHealth {
                await HealthService.authorize()
                slope = BodyInsights.slope(weights: await HealthService.weights(since: since), intake: DailyIntake.load(in: context, since: since))
            }
            let muscle = exercise.muscleGroup
            let weekly = items.filter { byID[$0.exerciseID]?.muscleGroup == muscle }.reduce(0) { $0 + $1.sets }
            let plan = items.first { $0.exerciseID == id }.map { "\($0.sets) × \($0.repsMin)-\($0.repsMax) reps, RIR \($0.targetRIR)" } ?? ""
            let info = Context(plan: plan, weeklySets: muscle.isEmpty ? nil : weekly, decision: tweaks.first { $0.exerciseID == id }?.reason)
            asked += 1
            _ = try? await ask(key: key, facts: facts(name: exercise.name, perfs: perfs, slope: slope, context: info), context: context, cached: cached)
        }
    }

    /// A plateau, or the last session 5 % under the best of the three before.
    private static func needsReading(_ perfs: [SessionPerf], last: SessionPerf, id: UUID) -> Bool {
        if StagnationDetector.finding(exerciseID: id, perfs: perfs) != nil { return true }
        let before = perfs.dropLast().suffix(3).map(\.e1RM).max() ?? 0
        return before > 0 && last.e1RM < before * 0.95
    }

    /// Cached per exercise and session count, so the same history is never paid twice.
    static func ask(key: String, facts: String, context: ModelContext, cached: [AIInsight]) async throws -> String {
        if let hit = cached.first(where: { $0.kind == "progress" && $0.key == key }) { return hit.text }
        let data = try await GeminiClient.generateJSON(system: system, prompt: facts, schema: schema, maxOutputTokens: 400, timeout: 30)
        struct Answer: Decodable { var d: String }
        let text = try JSONDecoder().decode(Answer.self, from: data).d.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GeminiClient.GeminiError.badResponse }
        context.insert(AIInsight(kind: "progress", key: key, text: text))
        context.saveReportingFailure()
        return text
    }
}
