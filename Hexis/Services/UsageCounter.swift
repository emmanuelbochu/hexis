import Foundation

/// Counts how often the secondary screens are opened, so the ones that never serve can be removed (Tools/usage.py reads it).
/// Lives in UserDefaults under a per-profile key and travels with the backup (`BackupPreferences`).
nonisolated enum UsageCounter {
    enum Feature: String, CaseIterable, Codable {
        case analyse, time, weekReview, exerciseProgress, exerciseSheet, pantry, nutritionPlan, gyms, adjustments, exerciseDetails
    }

    struct Entry: Codable, Equatable {
        var count: Int
        var last: Date
    }

    private static func key(_ profile: String) -> String { "usage.\(profile)" }

    static func hit(_ feature: Feature, now: Date = .now, profile: String = "default", defaults: UserDefaults = .standard) {
        var all = entries(profile: profile, defaults: defaults)
        let previous = all[feature]?.count ?? 0
        all[feature] = Entry(count: previous + 1, last: now)
        save(all, profile: profile, defaults: defaults)
    }

    static func entries(profile: String = "default", defaults: UserDefaults = .standard) -> [Feature: Entry] {
        guard let data = defaults.data(forKey: key(profile)),
              let raw = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { name, entry in Feature(rawValue: name).map { ($0, entry) } })
    }

    /// Restores counts from a backup; the bigger count wins so a restore never loses uses.
    static func merge(_ other: [String: Entry], profile: String = "default", defaults: UserDefaults = .standard) {
        var all = entries(profile: profile, defaults: defaults)
        for (name, entry) in other {
            guard let feature = Feature(rawValue: name) else { continue }
            if let mine = all[feature], mine.count >= entry.count { continue }
            all[feature] = entry
        }
        save(all, profile: profile, defaults: defaults)
    }

    private static func save(_ all: [Feature: Entry], profile: String, defaults: UserDefaults) {
        let raw = Dictionary(uniqueKeysWithValues: all.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) { defaults.set(data, forKey: key(profile)) }
    }
}
