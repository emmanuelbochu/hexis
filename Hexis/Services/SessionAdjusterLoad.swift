import Foundation
import SwiftData

/// Reads the history of a gym and works out the adjustments of the coming session.
extension SessionAdjuster {
    /// Reads the history of this gym and works out the adjustments of the coming session of a template.
    /// `persist` (when the session starts) writes the lasting tweaks; the home screen only reads them.
    static func load(
        template: WorkoutTemplate, gymID: UUID?, context: ModelContext, now: Date = .now,
        excluding sessionID: UUID? = nil, persist: Bool = false
    ) -> SessionAdjustments {
        let cycle = TrainingCycle.load(context: context)
        let blocks = template.blocks.sorted { $0.order < $1.order }
        let rehabNames = Set(ProgramCatalog.rehabExercises.map { $0.name.lowercased() })
        let exercises = Dictionary(((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func name(_ id: UUID) -> String { exercises[id]?.name ?? "Exercice" }
        func trained(_ id: UUID) -> Bool {
            let n = name(id)
            return !rehabNames.contains(n.lowercased()) && (ProgramCatalog.exercise(named: n)?.unit ?? "").isEmpty
        }

        let stored = ((try? context.fetch(FetchDescriptor<ExerciseTweak>(predicate: #Predicate { $0.gymID == gymID }))) ?? [])
        let tweaks = Dictionary(stored.map { ($0.exerciseID, Tweak(setsDelta: $0.setsDelta, repsShift: $0.repsShift, since: $0.since, reason: $0.reason)) }, uniquingKeysWith: { first, _ in first })

        // Weekly sets per muscle over the week this session belongs to (usual or 3-session), tweaks included.
        var weekly: [String: Int] = [:]
        for item in ProgramCatalog.week(of: template, in: template.program?.templates ?? [template]).flatMap({ $0.blocks.flatMap(\.exercises) }) {
            weekly[exercises[item.exerciseID]?.muscleGroup ?? "", default: 0] += item.sets + (tweaks[item.exerciseID]?.setsDelta ?? 0)
        }
        // Sets per muscle in this session, tweaks included.
        var sessionSets: [String: Int] = [:]
        for item in blocks.flatMap(\.exercises) {
            sessionSets[exercises[item.exerciseID]?.muscleGroup ?? "", default: 0] += item.sets + (tweaks[item.exerciseID]?.setsDelta ?? 0)
        }
        var plan: [PlanItem] = []
        for block in blocks {
            let items = block.exercises.sorted { $0.order < $1.order }
            for (i, item) in items.enumerated() where trained(item.exerciseID) && !plan.contains(where: { $0.id == item.exerciseID }) {
                let muscle = exercises[item.exerciseID]?.muscleGroup ?? ""
                plan.append(PlanItem(
                    id: item.exerciseID, name: name(item.exerciseID), muscle: muscle, sets: item.sets,
                    repsMin: item.repsMin, repsMax: item.repsMax, rest: item.restSeconds, step: item.progressionStep,
                    priority: ProgramCatalog.isPriority(muscle: muscle),
                    canAddSet: i == 0 || (items.first?.sets ?? 0) > item.sets, alone: items.count == 1, sessionSets: sessionSets[muscle] ?? 0,
                    weeklySets: weekly[muscle] ?? 0, maxWeeklySets: ProgramCatalog.maxWeeklySets(muscle: muscle)
                ))
            }
        }

        let ids = plan.map(\.id)
        let current = sessionID ?? UUID()
        let sets = ((try? context.fetch(FetchDescriptor<SetLog>(
            predicate: #Predicate { ids.contains($0.exerciseID) && $0.gymID == gymID && $0.kindRaw == "work" && $0.sessionID != current }
        ))) ?? []).filter { !cycle.isDeload($0.completedAt) && !HistorySeed.isImported($0.sessionID) }  // imported history only calibrates the weights
        let feelings = (try? context.fetch(FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { (ids.contains($0.exerciseID) || $0.exerciseID == $0.sessionID) && $0.sessionID != current }))) ?? []
        // The weeks of the cycle (at most 26 are looked at) and the last session: no need for the whole history.
        let horizon = Calendar.current.date(byAdding: .weekOfYear, value: -27, to: now) ?? .distantPast
        let finished = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw == "finished" && $0.id != current && $0.startedAt >= horizon }
        ))) ?? []
        var latest = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw == "finished" && $0.id != current }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        latest.fetchLimit = 1
        let lastStart = (try? context.fetch(latest))?.first?.startedAt
        let daysAway = lastStart.map { Calendar.current.dateComponents([.day], from: $0, to: now).day ?? 0 } ?? 0

        var result = compute(
            plan: plan, sets: sets, feelings: feelings, tweaks: tweaks, isDeload: cycle.isDeload(now),
            isRestart: cycle.isRestartWeek(now, sessionDates: finished.map(\.startedAt)), daysAway: daysAway, underfed: PlanAutoAdjust.isUnderfed(now: now), now: now
        )
        if let rehab = Rehab.load(context: context, now: now) {
            result.rehab = rehab
            if blocks.contains(where: { $0.exercises.contains { rehabNames.contains(name($0.exerciseID).lowercased()) } }),
               let note = Rehab.note(rehab, name: ProgramCatalog.rehab?.name ?? "Réhab") {
                result.notes.insert(note, at: 0)
            }
        }
        if persist { save(result.tweaks, existing: stored, gymID: gymID, context: context) }
        return result
    }

    private static func save(_ tweaks: [UUID: Tweak?], existing: [ExerciseTweak], gymID: UUID?, context: ModelContext) {
        guard !tweaks.isEmpty else { return }
        for (id, wanted) in tweaks {
            let found = existing.first { $0.exerciseID == id }
            switch (found, wanted) {
            case let (row?, tweak?):
                guard row.setsDelta != tweak.setsDelta || row.repsShift != tweak.repsShift else { continue }
                row.setsDelta = tweak.setsDelta
                row.repsShift = tweak.repsShift
                row.since = tweak.since
                row.reason = tweak.reason
            case let (nil, tweak?):
                context.insert(ExerciseTweak(exerciseID: id, gymID: gymID, setsDelta: tweak.setsDelta, repsShift: tweak.repsShift, since: tweak.since, reason: tweak.reason))
            case let (row?, nil):
                context.delete(row)
            case (nil, nil):
                continue
            }
        }
        context.saveReportingFailure()
    }
}
