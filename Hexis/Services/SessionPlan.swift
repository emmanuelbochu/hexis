import Foundation

/// Turns a stored template into this session's blocks: the app's adjustments applied (sets, rep range, RIR, deload),
/// the rehab slot filled with the current phase (or dropped once the rehab is over).
enum SessionPlan {
    static func blocks(
        template: WorkoutTemplate, exercises: [UUID: Exercise], adjustments: SessionAdjustments
    ) -> [WorkoutPlanner.BlockInput] {
        let byName = Dictionary(exercises.values.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        return template.blocks.sorted { $0.order < $1.order }.compactMap { block in
            let items = block.exercises.sorted { $0.order < $1.order }
            let names = items.map { exercises[$0.exerciseID]?.name ?? "" }
            if let rehab = ProgramCatalog.rehab, let slot = Rehab.slot(of: names, in: rehab) {
                let status = adjustments.rehab
                guard !(status?.done ?? false) else { return nil }
                let phase = rehab.phases.indices.contains(status?.phase ?? 0) ? rehab.phases[status?.phase ?? 0] : [:]
                let inputs = (phase[slot] ?? []).compactMap { spec in byName[spec.name.lowercased()].map { rehabInput(spec, $0) } }
                return inputs.isEmpty ? nil : WorkoutPlanner.BlockInput(sequential: true, exercises: inputs)
            }
            let inputs = items.map { item in
                input(item, exercise: exercises[item.exerciseID], adjustments: adjustments)
            }
            return WorkoutPlanner.BlockInput(exercises: inputs)
        }
    }

    private static func input(_ item: TemplateExercise, exercise: Exercise?, adjustments: SessionAdjustments) -> WorkoutPlanner.Input {
        let name = exercise?.name ?? "Exercice"
        let info = ProgramCatalog.exercise(named: name)
        var sets = max(item.sets + (adjustments.setsDelta[item.exerciseID] ?? 0), 1)
        let unit = info?.unit ?? ""
        // Deload: same loads, half the sets (rounded up); durations (cardio) stay as planned.
        if adjustments.isDeload, unit.isEmpty { sets = (sets + 1) / 2 }
        let shift = adjustments.repsShift[item.exerciseID] ?? 0
        return WorkoutPlanner.Input(
            exerciseID: item.exerciseID, name: name, muscle: exercise?.muscleGroup ?? "",
            isUnilateral: exercise?.isUnilateral ?? false, sets: sets,
            repsMin: max(item.repsMin + shift, 1), repsMax: max(item.repsMax + shift, 1),
            rest: item.restSeconds, targetRIR: adjustments.rirFloor.map { max(item.targetRIR, $0) } ?? min(item.targetRIR + adjustments.rirDelta, 4), tempo: item.tempo,
            step: item.progressionStep, unit: unit, canWarmUp: unit.isEmpty && item.progressionStep > 0,
            warmups: ProgramCatalog.writesWarmups
                ? (info?.warmups ?? []).compactMap { $0.count == 2 && (0.05...1).contains($0[0]) ? (percent: $0[0], reps: max(Int($0[1]), 1)) : nil }
                : nil
        )
    }

    private static func rehabInput(_ spec: ProgramSpec.Exercise, _ exercise: Exercise) -> WorkoutPlanner.Input {
        WorkoutPlanner.Input(
            exerciseID: exercise.id, name: exercise.name, muscle: exercise.muscleGroup, isUnilateral: spec.unilateral,
            sets: spec.sets, repsMin: spec.repsMin, repsMax: spec.repsMax, rest: spec.rest, targetRIR: spec.rir,
            tempo: spec.tempo, step: spec.step, unit: spec.unit, canWarmUp: false
        )
    }
}
