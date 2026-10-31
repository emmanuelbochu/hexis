import Foundation

/// The two top-level parts of the app, picked from the switcher at the top.
enum AppMode: String, CaseIterable, Identifiable {
    case workout, nutrition

    var id: String { rawValue }

    var label: String {
        switch self {
        case .workout: "Muscu"
        case .nutrition: "Alimentation"
        }
    }

    var systemImage: String {
        switch self {
        case .workout: "dumbbell.fill"
        case .nutrition: "fork.knife"
        }
    }
}
