import Foundation

struct WorkoutStep: Identifiable, Equatable {
    let id = UUID()
    var exerciseID: UUID
    var name: String
    /// "1a" / "1b" for supersets, nil otherwise.
    var label: String?
    var setNumber: Int
    var side: SetSide?
    var repsMin: Int
    var repsMax: Int
    var targetRIR: Int
    var tempo: String
    var progressionStep: Double
    /// Fraction of the work weight for a warmup step, nil for a work step.
    var warmupPercent: Double?
    /// Rest to take once this step is validated (0 = chain immediately).
    var restAfter: Int
    /// Index of the template block this step belongs to.
    var blockIndex = 0
    /// "s" or "min" when the reps are a duration.
    var unit = ""
}

/// Pure step generation: flattens a template into the ordered list of sets to perform.
enum WorkoutPlanner {
    /// One exercise with the values of this session (the app may have changed sets, reps or effort from the plan).
    struct Input {
        var exerciseID: UUID
        var name: String
        var muscle = ""
        var isUnilateral = false
        var sets: Int
        var repsMin: Int
        var repsMax: Int
        var rest: Int
        var targetRIR: Int
        var tempo = ""
        var step: Double
        var unit = ""
        /// False for rehab, durations and bodyweight moves.
        var canWarmUp = true
        /// Ramp-up sets the program wrote (% of the work weight, reps); nil = the app decides, [] = none.
        var warmups: [(percent: Double, reps: Int)]?
    }

    struct BlockInput {
        /// Done one exercise after the other instead of as a superset (rehab).
        var sequential = false
        var exercises: [Input]
    }

    /// Warmups: the sheet's 40/70/85 % on the session's first exercise only, plus one feeler set at 60 % on the first heavy
    /// exercise done alone (10 reps or fewer) of the other body region (upper/lower). Nothing else warms up.
    static func steps(
        for blocks: [BlockInput], unilateralRest: Int = 15, warmupPercents: [Double] = []
    ) -> [WorkoutStep] {
        var result: [WorkoutStep] = []
        var warmedAny = false
        var warmRegions: Set<Bool> = []
        for (bi, block) in blocks.enumerated() {
            let blockStart = result.count
            defer { for i in blockStart..<result.count { result[i].blockIndex = bi } }
            guard let first = block.exercises.first else { continue }
            if let written = first.warmups {
                if first.canWarmUp, !written.isEmpty {
                    result += written.enumerated().map { i, w in
                        warmup(first, index: i, percent: w.percent, reps: w.reps)
                    }
                }
            } else if first.canWarmUp, !warmupPercents.isEmpty {
                let alone = block.exercises.count == 1 || block.sequential
                let lower = WarmupCalculator.isLowerBody(muscle: first.muscle)
                let firstOfSession = !warmedAny
                if firstOfSession || (alone && first.repsMax <= 10 && !warmRegions.contains(lower)) {
                    result += warmups(first, percents: firstOfSession ? warmupPercents : [0.6], reps: firstOfSession ? nil : 6)
                    warmRegions.insert(lower)
                    warmedAny = true
                }
            }
            if block.exercises.count == 1 || block.sequential {
                for ex in block.exercises {
                    for set in 1...max(ex.sets, 1) {
                        result += sets(ex, label: nil, set: set, rest: ex.rest, unilateralRest: unilateralRest)
                    }
                }
                continue
            }
            // Superset: rounds of every exercise, then the extra sets of the ones with more, each alone.
            let rounds = max(block.exercises.map(\.sets).min() ?? 1, 1)
            for round in 1...rounds {
                for (i, ex) in block.exercises.enumerated() {
                    let isLast = i == block.exercises.count - 1
                    result += sets(ex, label: "\(bi + 1)\(letter(i))", set: round, rest: isLast ? ex.rest : 0, unilateralRest: unilateralRest)
                }
            }
            for (i, ex) in block.exercises.enumerated() {
                for extra in 0..<max(ex.sets - rounds, 0) {
                    result += sets(ex, label: "\(bi + 1)\(letter(i))", set: rounds + extra + 1, rest: ex.rest, unilateralRest: unilateralRest)
                }
            }
        }
        if !result.isEmpty { result[result.count - 1].restAfter = 0 }
        return result
    }

    private static func sets(_ ex: Input, label: String?, set: Int, rest: Int, unilateralRest: Int) -> [WorkoutStep] {
        func step(_ side: SetSide?, _ rest: Int) -> WorkoutStep {
            WorkoutStep(
                exerciseID: ex.exerciseID, name: ex.name, label: label, setNumber: set, side: side,
                repsMin: ex.repsMin, repsMax: ex.repsMax, targetRIR: ex.targetRIR,
                tempo: ex.tempo, progressionStep: ex.step,
                warmupPercent: nil, restAfter: rest, unit: ex.unit
            )
        }
        guard ex.isUnilateral else { return [step(nil, rest)] }
        return [step(.left, unilateralRest), step(.right, rest)]
    }

    private static func warmups(_ ex: Input, percents: [Double], reps: Int?) -> [WorkoutStep] {
        percents.enumerated().map { i, percent in warmup(ex, index: i, percent: percent, reps: reps ?? WarmupCalculator.reps(forWarmup: i)) }
    }

    private static func warmup(_ ex: Input, index i: Int, percent: Double, reps count: Int) -> WorkoutStep {
        WorkoutStep(
            exerciseID: ex.exerciseID, name: ex.name, label: nil, setNumber: i + 1, side: nil,
            repsMin: count, repsMax: count,
            targetRIR: ex.targetRIR, tempo: "", progressionStep: ex.step,
            warmupPercent: percent, restAfter: WarmupCalculator.rest(forWarmup: i)
        )
    }

    private static func letter(_ index: Int) -> String {
        String(UnicodeScalar(UInt8(97 + index % 26)))
    }
}
