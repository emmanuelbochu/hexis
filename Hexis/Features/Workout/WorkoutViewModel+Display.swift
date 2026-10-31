import Foundation
import SwiftData

/// What the session screen shows: groups, card states, titles and rows.
extension WorkoutViewModel {
    struct ExerciseGroup: Identifiable {
        var id: String { "\(blockIndex)-\(exerciseID)" }
        var exerciseID: UUID
        var name: String
        var label: String?
        var blockIndex: Int
        /// Step positions of this exercise, in planned order.
        var indices: [Int]
    }

    func rebuildGroups() {
        var result: [ExerciseGroup] = []
        for (i, step) in steps.enumerated() {
            if let g = result.firstIndex(where: { $0.exerciseID == step.exerciseID && $0.blockIndex == step.blockIndex }) {
                result[g].indices.append(i)
                // Warmups come first and carry no superset label: the work sets tell.
                if result[g].label == nil { result[g].label = step.label }
            } else {
                result.append(.init(
                    exerciseID: step.exerciseID, name: step.name, label: step.label, blockIndex: step.blockIndex, indices: [i]
                ))
            }
        }
        groups = result
        let blocks = Set(result.filter { $0.label != nil }.map(\.blockIndex)).sorted()
        supersetOrder = Dictionary(uniqueKeysWithValues: blocks.enumerated().map { ($0.element, $0.offset) })
    }

    enum CardState { case active, partner, upcoming, finished }

    /// Which card the user is on: the active exercise, its superset partner(s), the rest to come, or done.
    func cardState(_ target: ExerciseGroup) -> CardState {
        if target.indices.allSatisfy({ done.contains($0) || skipped.contains($0) }) { return .finished }
        guard let current = currentIndex, let active = group(containing: current) else { return .upcoming }
        if active.id == target.id { return .active }
        return active.blockIndex == target.blockIndex ? .partner : .upcoming
    }

    /// Position of the group's superset among the session's supersets (nil when it is a single exercise).
    func supersetIndex(_ group: ExerciseGroup) -> Int? {
        group.label == nil ? nil : supersetOrder[group.blockIndex]
    }

    func group(containing index: Int?) -> ExerciseGroup? {
        guard let index, steps.indices.contains(index) else { return nil }
        return groups.first { $0.indices.contains(index) }
    }

    /// Row label: "W" for a warmup, else the work set number (with side for unilateral).
    func rowLabel(_ i: Int) -> String {
        let step = steps[i]
        if step.warmupPercent != nil { return "W\(step.setNumber)" }
        return "\(step.setNumber)" + (step.side.map { $0 == .left ? "G" : "D" } ?? "")
    }

    /// Same set in the previous session in this gym, e.g. "60×10".
    func previousText(_ i: Int) -> String {
        let step = steps[i]
        guard step.warmupPercent == nil else { return "–" }
        let ordinal = steps[..<i].filter {
            $0.warmupPercent == nil && $0.exerciseID == step.exerciseID && $0.blockIndex == step.blockIndex
        }.count
        let previous = previousSets(of: step.exerciseID)
        guard previous.indices.contains(ordinal) else { return "–" }
        return "\(previous[ordinal].weight.formatted())×\(previous[ordinal].reps)"
    }

    /// Everything done on the exercise before this session (read once), to tell a real record.
    private func history(of exerciseID: UUID) -> [LiveRecord.Prior] {
        if let cached = priorCache[exerciseID] { return cached }
        let current = session.id
        let started = session.startedAt
        let sets = (try? context.fetch(FetchDescriptor<SetLog>(
            predicate: #Predicate { $0.exerciseID == exerciseID && $0.kindRaw == "work" && $0.sessionID != current && $0.completedAt < started }
        ))) ?? []
        let prior = sets.map { LiveRecord.Prior(weight: $0.weight, reps: $0.reps) }
        priorCache[exerciseID] = prior
        return prior
    }

    /// The sets of the exercise that set a record today, by row.
    func records(_ group: ExerciseGroup) -> [Int: LiveRecord.Kind] {
        let done = group.indices.sorted().compactMap { i -> (index: Int, weight: Double, reps: Int)? in
            guard steps[i].warmupPercent == nil, self.done.contains(i), let v = values[i] else { return nil }
            return (i, v.weight, v.reps)
        }
        guard !done.isEmpty else { return [:] }
        return LiveRecord.medals(done: done, history: history(of: group.exerciseID))
    }

    /// How to do it, from the program file.
    func cue(_ group: ExerciseGroup) -> String? {
        ProgramCatalog.exercise(named: group.name).map(\.cue).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Column title of the reps: a duration for holds and cardio.
    func repsTitle(_ group: ExerciseGroup) -> String {
        switch group.indices.first.map({ steps[$0].unit }) {
        case "s": "SEC"
        case "min": "MIN"
        default: "REPS"
        }
    }

    /// The one line always shown: "3 × 8–10 reps · RIR 2" (hers: "· reste +2").
    func subtitle(_ group: ExerciseGroup) -> String {
        let work = group.indices.filter { steps[$0].warmupPercent == nil }
        guard let i = work.first else { return "" }
        let step = steps[i]
        let unit = step.unit.isEmpty ? "reps" : step.unit
        let range = step.repsMin == step.repsMax ? "\(step.repsMin)" : "\(step.repsMin)–\(step.repsMax)"
        let sets = Set(work.map { steps[$0].setNumber }).count
        return "\(sets) × \(range) \(unit) · \(EffortScale.target(rir: step.targetRIR))"
    }

    /// What the unfolded card tells: how to do it, tempo, how the weight is typed, and what the app changed.
    func details(_ group: ExerciseGroup) -> [String] {
        var lines: [String] = []
        if let cue = cue(group) { lines.append(cue) }
        var facts: [String] = []
        if let step = group.indices.first.map({ steps[$0] }), !step.tempo.isEmpty { facts.append("Tempo \(step.tempo)") }
        if group.indices.first.map({ steps[$0].unit.isEmpty }) ?? true {
            facts.append(loadProfile(group.exerciseID, name: group.name).kind.unitHint.prefix(1).uppercased() + loadProfile(group.exerciseID, name: group.name).kind.unitHint.dropFirst())
        }
        if isDeload { facts.append("Déload : mêmes charges, moitié des séries") }
        if !facts.isEmpty { lines.append(facts.joined(separator: " · ")) }
        lines += adjustments.notes.filter { $0.exerciseID == group.exerciseID }.map(\.text)
        if let text = diagnosis(group.exerciseID) { lines.append(text) }
        return lines
    }

    /// The app changed something for this exercise (a dot on the folded card).
    func isAdjusted(_ group: ExerciseGroup) -> Bool {
        adjustments.notes.contains { $0.exerciseID == group.exerciseID }
    }
}
