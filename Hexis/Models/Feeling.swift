import Foundation

/// One-tap feeling for an exercise in a session: a quick read of how it went.
enum Feeling: String, CaseIterable, Identifiable, Codable {
    /// Lots left in the tank: ready for more load.
    case easy
    case good
    /// Harder than planned.
    case hard
    /// Low energy, not at my best.
    case tired
    /// Discomfort or pain: flagged at the next session.
    case pain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Facile"
        case .good: "Bien"
        case .hard: "Intense"
        case .tired: "Fatigué"
        case .pain: "Gêne"
        }
    }

    var symbol: String {
        switch self {
        case .easy: "bolt.fill"
        case .good: "face.smiling"
        case .hard: "flame.fill"
        case .tired: "battery.25percent"
        case .pain: "exclamationmark.triangle.fill"
        }
    }
}
