import Foundation

/// Pure double progression: top of the rep range on every set ⇒ about +2.5 % load (at least one machine step), and the reps
/// the same strength gives at the new weight. Effort refines it: far past the planned effort the load is held; very easy
/// (2+ under the target) adds twice as much. Inside the range, one more rep when the last effort left room.
enum Progression {
    struct Target: Equatable {
        var weight: Double
        var reps: Int
        var increased: Bool
    }

    /// The plan's +2.5-5 %: 2.5 % rounded to the machine step, never less than one step.
    static func increment(weight: Double, step: Double) -> Double {
        guard step > 0 else { return 0 }
        return max(step, (weight * 0.025 / step).rounded() * step)
    }

    /// Reps the same strength gives at another weight (Epley).
    static func reps(from weight: Double, reps: Int, to newWeight: Double) -> Int {
        guard weight > 0, newWeight > 0 else { return reps }
        let e1RM = Performance.e1RM(weight: weight, reps: reps)
        return Int((30 * (e1RM / newWeight - 1)).rounded(.down))
    }

    static func target(
        lastSets: [(weight: Double, reps: Int)], repsMin: Int, repsMax: Int, step: Double,
        averageRPE: Double? = nil, targetRPE: Double? = nil
    ) -> Target? {
        let lastSets = withoutTypos(lastSets)
        guard let heaviest = lastSets.map(\.weight).max() else { return nil }
        let atWeight = lastSets.filter { $0.weight == heaviest }
        let lowest = atWeight.map(\.reps).min() ?? repsMin

        // The range moved (new program, range changed after a plateau): start again from the weight that fits
        // the bottom of the new range at the planned effort.
        if heaviest > 0, step > 0, lowest < repsMin - 2 || lowest > repsMax + 2,
           let best = atWeight.map({ Performance.e1RM(weight: heaviest, reps: $0.reps) }).max() {
            let reserve = 10 - (targetRPE ?? 8)
            let raw = best / (1 + (Double(repsMin) + reserve) / 30)
            // Bounded: a typo in the reps must not send the weight flying.
            let weight = max(step, (min(raw, heaviest * 1.2) / step).rounded() * step)
            return Target(weight: weight, reps: repsMin, increased: weight > heaviest)
        }

        if atWeight.allSatisfy({ $0.reps >= repsMax }) {
            if let averageRPE, let targetRPE, averageRPE > targetRPE + 1 {
                return Target(weight: heaviest, reps: repsMax, increased: false)
            }
            var add = increment(weight: heaviest, step: step)
            if let averageRPE, let targetRPE, averageRPE <= targetRPE - 2 { add *= 2 }
            guard add > 0 else { return Target(weight: heaviest, reps: repsMax, increased: false) }
            let weight = heaviest + add
            let count = min(max(Self.reps(from: heaviest, reps: lowest, to: weight), repsMin), repsMax)
            return Target(weight: weight, reps: count, increased: true)
        }

        let room = averageRPE.map { average in targetRPE.map { average <= $0 } ?? true } ?? true
        return Target(weight: heaviest, reps: min(max(lowest + (room ? 1 : 0), repsMin), repsMax), increased: false)
    }

    /// The adjuster's weight shift on top of a goal. A cut is not stacked on a goal already brought down by the reps (failed range:
    /// the weight restarted lower), otherwise 18 kg at 9/9/7 reps becomes 15.7 then, snapped down, 14 (−22 % for a « −1 kg » note).
    static func shifted(_ target: Target, by shift: Double, heaviest: Double?, step: Double) -> Target {
        if shift < 0, let heaviest, target.weight < heaviest { return target }
        var out = target
        out.weight = max(step, target.weight + shift)
        out.increased = shift > 0
        return out
    }

    /// Same weight and reps as last time (deload week, or a load already raised this week).
    static func hold(lastSets: [(weight: Double, reps: Int)], repsMin: Int, repsMax: Int) -> Target? {
        let lastSets = withoutTypos(lastSets)
        guard let heaviest = lastSets.map(\.weight).max() else { return nil }
        let lowest = lastSets.filter { $0.weight == heaviest }.map(\.reps).min() ?? repsMin
        return Target(weight: heaviest, reps: min(max(lowest, repsMin), repsMax), increased: false)
    }

    /// A weight typed with one zero too many (« 800 » for 80) would become next session's goal: sets far above
    /// the others of the same session (3× the lower median: an extra zero, never a real pyramid) are left out.
    static func withoutTypos(_ sets: [(weight: Double, reps: Int)]) -> [(weight: Double, reps: Int)] {
        let weights = sets.map(\.weight).sorted()
        guard weights.count >= 2 else { return sets }
        let usual = weights[(weights.count - 1) / 2]
        return usual > 0 ? sets.filter { $0.weight <= usual * 3 } : sets
    }
}
