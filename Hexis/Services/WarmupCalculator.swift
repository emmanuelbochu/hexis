import Foundation

/// Pure warmup math: ~40 % × 8-10, 70 % × 4, 85-90 % × 1-2 of the work weight, rounded to the machine step.
enum WarmupCalculator {
    static let defaultPercents: [Double] = [0.4, 0.7, 0.875]
    static let defaultReps: [Int] = [8, 4, 2]
    static let defaultRests: [Int] = [30, 45, 60]

    static func weight(work: Double, percent: Double, step: Double) -> Double {
        guard work > 0, step > 0 else { return 0 }
        let raw = work * percent
        return max((raw / step).rounded() * step, 0)
    }

    private static let lowerBody: Set<String> = ["Quadriceps", "Ischios", "Fessiers", "Mollets"]

    /// Upper or lower body: a region already warm needs one feeler set on its next lift, not the full ramp.
    static func isLowerBody(muscle: String) -> Bool { lowerBody.contains(muscle) }

    static func reps(forWarmup index: Int) -> Int {
        defaultReps[min(index, defaultReps.count - 1)]
    }

    static func rest(forWarmup index: Int) -> Int {
        defaultRests[min(index, defaultRests.count - 1)]
    }
}
