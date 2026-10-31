import Foundation

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, snack, dinner, evening

    var id: String { rawValue }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var label: String {
        switch self {
        case .breakfast: "Petit-déj"
        case .lunch: "Déjeuner"
        case .snack: "Collation"
        case .dinner: "Dîner"
        case .evening: "Après dîner"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: "cup.and.saucer.fill"
        case .lunch: "fork.knife"
        case .snack: "carrot.fill"
        case .dinner: "moon.stars.fill"
        case .evening: "bed.double.fill"
        }
    }

    /// The meal that fits the time of day.
    static func current(hour: Int = Calendar.current.component(.hour, from: .now)) -> MealSlot {
        switch hour {
        case ..<10: .breakfast
        case 10..<15: .lunch
        case 15..<18: .snack
        case 18..<21: .dinner
        default: .evening
        }
    }
}
