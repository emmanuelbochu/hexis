import Foundation

/// What the nutrition follows. The daily calories and macros are the plan's own (`PlanAutoAdjust` moves the plan itself).
enum NutritionGoals {
    /// The phase followed (the program's lean bulk) and its weekly weight range.
    static let phase: NutritionPhase.Kind = .bulk

    /// Protein aimed at: 1.6 to 2.2 g per kg of the last weight (125 to 170 g without a weight).
    static func proteinRange(weightKg: Double?) -> ClosedRange<Double> {
        guard let weightKg, weightKg > 30 else { return 125...170 }
        return (weightKg * 1.6).rounded()...(weightKg * 2.2).rounded()
    }
}
