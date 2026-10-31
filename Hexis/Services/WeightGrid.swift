import Foundation

/// The weights a machine really offers, learned from what was typed on it (exercise × gym): a cable stack at 41 / 45.5 kg never
/// gets « 43.5 kg ». The smallest gap between two weights used is the machine's step; the grid goes on past the lightest and the
/// heaviest weights with that step. Too little history (fewer than 2 weights) leaves the suggestion as it is.
enum WeightGrid {
    /// Work weights typed on this exercise in this gym, cleaned: no zero, no typo (×10 by mistake).
    static func known(_ weights: [Double]) -> [Double] {
        let positive = weights.filter { $0 > 0 && $0.isFinite }.sorted()
        guard !positive.isEmpty else { return [] }
        let median = positive[positive.count / 2]
        let kept = positive.filter { $0 <= median * 1.45 && $0 >= median * 0.3 }
        // Same weight typed as 41 and 41.0000001: one value.
        return kept.reduce(into: [Double]()) { out, w in if let last = out.last, w - last < 0.05 { return }; out.append(w) }
    }

    /// The machine's step: the smallest gap between two weights used (nil with fewer than 2).
    static func step(_ known: [Double]) -> Double? {
        zip(known, known.dropFirst()).map { $1 - $0 }.filter { $0 >= 0.25 }.min()
    }

    /// Every gap is a whole number of steps (a regular stack or plate set): weights between the known ones exist too.
    static func isRegular(_ known: [Double], step: Double) -> Bool {
        zip(known, known.dropFirst()).allSatisfy { pair in
            let ratio = (pair.1 - pair.0) / step
            return abs(ratio - ratio.rounded()) * step <= max(0.3, 0.1 * step)
        }
    }

    /// The suggestion placed on a weight that exists: the machine's step from its lightest weight used (plus the weights really
    /// typed). Going up (`target` above `last`): the first at or above it; going down: the first at or below it (or the one above if it is within 3 %); holding: the
    /// nearest. A step wider than twice the program's (`maxStep`) is not trusted (30 and 40 kg seen only: the plates between exist).
    static func snap(_ target: Double, known: [Double], last: Double?, maxStep: Double = .infinity) -> Double {
        guard target > 0, let step = step(known), step <= maxStep + 0.01, let low = known.first, let high = known.last else { return target }
        var grid = Set(known.map { ($0 * 100).rounded() / 100 })
        if isRegular(known, step: step) {
            var w = low
            while w > step, w > target - 2 * step { w -= step; grid.insert((w * 100).rounded() / 100) }
            w = low
            while w < target + 2 * step { w += step; grid.insert((w * 100).rounded() / 100) }
        } else {
            // Uneven weights (39, 45, 50, 54: a stack with half plates, dumbbells 15, 16, 17.5): nothing is invented between them,
            // only the real ones, then the program's step beyond the lightest and the heaviest. Two weights very far apart (a one-off
            // heavy set: 40 then 72.5) are no step of the machine: the program's step fills around the target.
            let unit = maxStep.isFinite ? maxStep / 2 : step
            let wide = maxStep.isFinite ? 2 * maxStep : 4 * step
            for (a, b) in zip(known, known.dropFirst()) where b - a > wide {
                var w = a
                while w + unit < b, w < target + 2 * unit {
                    w += unit
                    if w > target - 2 * unit { grid.insert((w * 100).rounded() / 100) }
                }
            }
            var w = high
            while w < target + 2 * unit { w += unit; grid.insert((w * 100).rounded() / 100) }
            w = low
            while w > unit, w > target - 2 * unit { w -= unit; grid.insert((w * 100).rounded() / 100) }
        }
        let sorted = grid.sorted()
        let near = 0.05
        if let hit = sorted.first(where: { abs($0 - target) < near }) { return hit }
        if let last, target > last + near { return sorted.first { $0 > target } ?? target }
        if let last, target < last - near {
            // Going down takes the real weight below, unless the one above is barely over the target (< 3 %): 44 → 45, not 39.
            if let above = sorted.first(where: { $0 > target }), above - target <= 0.03 * target { return above }
            return sorted.last { $0 < target } ?? target
        }
        return sorted.min { abs($0 - target) < abs($1 - target) } ?? target
    }
}
