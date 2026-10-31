import Foundation

/// The weight proposed for an exercise never done in this gym (a first session shows 0 kg and the warmups with it).
/// The program gives a starting weight for each lift (`start`, in the unit typed in the app); the more she has really lifted
/// on the others, the more they are scaled: the median of (best weight done / program's start) over the exercises with a
/// history, kept between ×0.5 and ×2.5 so one odd lift cannot throw the rest off. Rounded DOWN to the machine step: a first
/// set too light costs nothing, one too heavy does.
enum StartWeight {
    static let scaleRange = 0.5...2.5

    /// How strong she is compared with the program's starting weights (1 with no history).
    static func scale(_ pairs: [(actual: Double, start: Double)]) -> Double {
        let ratios = pairs.filter { $0.actual > 0 && $0.start > 0 && $0.actual.isFinite }.map { $0.actual / $0.start }.sorted()
        guard !ratios.isEmpty else { return 1 }
        let middle = ratios.count / 2
        let median = ratios.count % 2 == 1 ? ratios[middle] : (ratios[middle - 1] + ratios[middle]) / 2
        return min(max(median, scaleRange.lowerBound), scaleRange.upperBound)
    }

    static func weight(start: Double, scale: Double, step: Double) -> Double {
        guard start > 0, step > 0 else { return 0 }
        return max(step, (start * scale / step).rounded(.down) * step)
    }
}
