import Foundation
import SwiftData
@testable import HexisLogic

/// What must hold whatever the person does. Each check returns readable French lines (empty = fine).
@MainActor
enum LifeChecks {
    /// The session as the app built it, before the first set: bounds, weights, warmups, what it says.
    static func plan(_ vm: WorkoutViewModel, lastTop: [String: Double], gymID: UUID) -> [String] {
        var out: [String] = []
        if vm.steps.isEmpty { out.append("séance vide") }
        var workSets: [UUID: Int] = [:]
        for (i, step) in vm.steps.enumerated() {
            let name = step.name
            let value = vm.values[i]
            if step.repsMin < (step.unit.isEmpty ? 1 : 0) || step.repsMin > step.repsMax { out.append("\(name) : fourchette \(step.repsMin)–\(step.repsMax)") }
            if step.unit.isEmpty, step.repsMax > 30 { out.append("\(name) : \(step.repsMax) reps visées") }
            if !(0...5).contains(step.targetRIR) { out.append("\(name) : RIR \(step.targetRIR)") }
            if !(0...300).contains(step.restAfter) { out.append("\(name) : repos \(step.restAfter) s") }
            guard let value else {
                if !vm.skipped.contains(i) { out.append("\(name) : série sans valeur proposée") }
                continue
            }
            if !value.weight.isFinite || value.weight < 0 { out.append("\(name) : poids \(value.weight)") }
            if value.reps < 0 || value.reps > max(step.repsMax + 2, 40) { out.append("\(name) : \(value.reps) reps proposées") }
            if step.warmupPercent == nil {
                if step.side != .right { workSets[step.exerciseID, default: 0] += 1 }
                if !vm.isDeload, step.setNumber == 1, let top = lastTop[Athlete.key(step.exerciseID, gymID)], top > 0,
                   value.weight > top * 1.25 + 2 * step.progressionStep {  // very easy = two increments, whole steps on light loads
                    // What the goal was made of, to replay the cause instead of guessing it.
                    let seen = vm.previousSets(of: step.exerciseID).map { fmt($0.weight) }.joined(separator: "/")
                    let grid = vm.knownWeights(of: step.exerciseID).map(fmt).joined(separator: "/")
                    out.append("\(name) : saut de charge \(fmt(top)) → \(fmt(value.weight)) kg (dernière séance \(seen) ; machine \(grid) ; échelle ×\(fmt(vm.startScale())) ; semaine \(vm.isDeload ? "déload" : "normale"))")
                }
                // The mirror of the jump: a first set far UNDER what was lifted last time (its median set: one typo or one heavy
                // set is no reference), with no reason (deload, break, a tired or painful day).
                let lastWeights = vm.previousSets(of: step.exerciseID).map(\.weight).filter { $0 > 0 }.sorted()
                if !vm.isDeload, vm.adjustments.weightFactor >= 1, step.setNumber == 1, value.weight > 0, !lastWeights.isEmpty {
                    let usual = lastWeights[(lastWeights.count - 1) / 2]
                    // Reps far under the range (2+ below its bottom) restart the weight lower on purpose (`Progression.target`): a reason.
                    let previous = vm.previousSets(of: step.exerciseID)
                    let heaviest = previous.map(\.weight).max() ?? 0
                    let failedRange = (previous.filter { $0.weight == heaviest }.map(\.reps).min() ?? .max) < step.repsMin - 2
                    if !failedRange, value.weight < usual * 0.85 - step.progressionStep {
                        out.append("\(name) : chute de charge \(fmt(usual)) → \(fmt(value.weight)) kg sans raison (hors déload et reprise ; dernière séance \(lastWeights.map(fmt).joined(separator: "/")) à \(vm.previousSets(of: step.exerciseID).map { String($0.reps) }.joined(separator: "/")) reps, fourchette \(step.repsMin)–\(step.repsMax) ; décalage \(fmt(vm.adjustments.shift[step.exerciseID] ?? 0)) ; fatigué \(vm.isTired) ; machine \(vm.knownWeights(of: step.exerciseID).map(fmt).joined(separator: "/")))")
                    }
                }
            } else if let work = vm.steps.indices.first(where: { vm.steps[$0].exerciseID == step.exerciseID && vm.steps[$0].warmupPercent == nil }),
                      let workWeight = vm.values[work]?.weight, value.weight > workWeight, !vm.skipped.contains(i) {
                out.append("\(name) : échauffement \(fmt(value.weight)) kg > travail \(fmt(workWeight)) kg")
            }
        }
        for (id, count) in workSets where !(1...8).contains(count) {
            out.append("\(vm.steps.first { $0.exerciseID == id }?.name ?? "?") : \(count) séries")
        }
        let total = workSets.values.reduce(0, +)
        if total > 45 { out.append("\(total) séries de travail dans la séance") }
        out += notes(vm.adjustments.notes)
        return out
    }

    /// What the app writes to the person: no duplicate, no broken number, never the word « dur ».
    static func notes(_ notes: [SessionAdjustments.Note]) -> [String] {
        var out: [String] = []
        let ids = notes.map(\.id)
        if Set(ids).count != ids.count { out.append("note en double : \(ids)") }
        for note in notes {
            let text = note.text.lowercased()
            if text.trimmingCharacters(in: .whitespaces).isEmpty { out.append("note vide (\(note.id))") }
            if text.range(of: #"\bnan\b|\binf\b|-0\b|−0\b|\+0 |\bdure?s?\b"#, options: .regularExpression) != nil {
                out.append("texte suspect : « \(note.text) »")
            }
        }
        return out
    }

    /// The whole database: nothing orphaned, doubled, left open or out of bounds.
    static func store(_ context: ModelContext, now: Date) -> [String] {
        var out: [String] = []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<SetLog>())) ?? []
        let ids = Set(sessions.map(\.id))
        let orphans = logs.filter { !ids.contains($0.sessionID) }.count
        if orphans > 0 { out.append("\(orphans) séries sans séance") }
        // Same set ticked twice (old imported sessions numbered their sets per exercise, hence the exercise in the key).
        let doubled = Dictionary(grouping: logs, by: { "\($0.sessionID)-\($0.exerciseID)-\($0.index)-\($0.sideRaw ?? "")" }).values.filter { $0.count > 1 }.count
        if doubled > 0 { out.append("\(doubled) séries enregistrées deux fois") }
        if logs.contains(where: { !$0.weight.isFinite || $0.weight < 0 || $0.reps < 0 }) { out.append("série au poids ou aux reps impossibles") }
        let lastSet = Dictionary(grouping: logs, by: \.sessionID).mapValues { $0.map(\.completedAt).max() ?? .distantPast }
        for session in sessions {
            switch session.state {
            case .inProgress:
                let idle = now.timeIntervalSince(lastSet[session.id] ?? session.startedAt)
                if idle > SessionCloser.idleAfter + 60 { out.append("séance du \(day(session.startedAt)) restée ouverte \(Int(idle / 3600)) h") }
            case .finished:
                guard let end = session.endedAt else { out.append("séance terminée sans fin"); continue }
                if end < session.startedAt { out.append("séance finie avant d'avoir commencé") }
                if end.timeIntervalSince(session.startedAt) > 5 * 3600 { out.append("séance du \(day(session.startedAt)) de \(Int(end.timeIntervalSince(session.startedAt) / 3600)) h") }
                if lastSet[session.id] == nil { out.append("séance terminée sans aucune série") }
            }
        }
        let tweaks = (try? context.fetch(FetchDescriptor<ExerciseTweak>())) ?? []
        if Set(tweaks.map { "\($0.exerciseID)-\($0.gymID?.uuidString ?? "")" }).count != tweaks.count { out.append("ajustement durable en double") }
        for tweak in tweaks where !(-2...2).contains(tweak.setsDelta) || !(-4...4).contains(tweak.repsShift) {
            out.append("ajustement durable hors bornes : séries \(tweak.setsDelta), reps \(tweak.repsShift)")
        }
        let deloads = ((try? context.fetch(FetchDescriptor<DeloadWeek>())) ?? []).map(\.start).sorted()
        for (a, b) in zip(deloads, deloads.dropFirst()) where b.timeIntervalSince(a) < 21 * 86_400 {
            out.append("deux déloads à \(Int(b.timeIntervalSince(a) / 86_400)) jours d'écart")
        }
        return out
    }

    private static func fmt(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }
    private static func day(_ date: Date) -> String { date.formatted(.iso8601.month().day()) }
}
