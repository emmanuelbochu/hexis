import Foundation

/// What Home last proposed, kept so the real-data check can tell when the screen and the logic disagree.
nonisolated enum HomeShown {
    struct Record: Codable, Equatable {
        var date: Date
        var session: String
        var short: Bool
    }

    private static let key = "homeShown"

    static func save(_ record: Record, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    static func last(defaults: UserDefaults = .standard) -> Record? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Record.self, from: $0) }
    }
}
