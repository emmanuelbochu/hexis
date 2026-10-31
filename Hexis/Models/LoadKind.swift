import Foundation

/// What the number typed in the "kg" column means for an exercise.
enum LoadKind: String, CaseIterable, Identifiable {
    /// Weight of one side (barbell or plate-loaded machine): the real load is twice that, plus the bar.
    case perSide
    /// Weight of the stack, on a cable or a selectorized machine.
    case stack
    /// Weight of one dumbbell, held in each hand.
    case perHand
    /// The real total load.
    case total

    var id: String { rawValue }

    var unitHint: String {
        switch self {
        case .perSide: "kg par côté"
        case .stack: "kg poulie"
        case .perHand: "kg par haltère"
        case .total: "kg total"
        }
    }
}
