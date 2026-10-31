import Foundation

/// The phase followed (cut, maintenance, bulk); `PhaseCheck` compares it with the scale.
enum NutritionPhase {
    enum Kind: Equatable {
        case cut, maintain, bulk

        var title: String {
            switch self {
            case .cut: "Sèche"
            case .maintain: "Maintien"
            case .bulk: "Prise de masse"
            }
        }
    }
}
