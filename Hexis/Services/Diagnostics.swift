import Foundation

/// Journal of non-fatal anomalies (a failed save, an unreadable backup, a slow Gemini answer, a slow launch…), bounded to
/// `limit` entries. No screen shows it: Tools/weekly_build.py reads it from the backup and reports it in report.md.
/// Lives in UserDefaults under a per-profile key and travels with the backup (`BackupPreferences`).
nonisolated enum Diagnostics {
    enum Kind: String, Codable {
        case saveFailed, backupUnreadable, programSyncFailed, geminiFailed, nonFiniteValue, slowLaunch
    }

    struct Entry: Codable, Equatable {
        var date: Date
        var kind: Kind
        var detail: String
    }

    static let limit = 200
    /// Set when the process starts; `RootView` compares it with the first screen to spot slow launches.
    static let launchedAt = Date()
    static let slowLaunch: TimeInterval = 2

    private static func key(_ profile: String) -> String { "diagnostics.\(profile)" }

    static func record(_ kind: Kind, _ detail: String = "", now: Date = .now, profile: String = "default",
                       defaults: UserDefaults = .standard) {
        var all = entries(profile: profile, defaults: defaults)
        all.append(Entry(date: now, kind: kind, detail: String(detail.prefix(200))))
        save(Array(all.suffix(limit)), profile: profile, defaults: defaults)
    }

    static func entries(profile: String = "default", defaults: UserDefaults = .standard) -> [Entry] {
        guard let data = defaults.data(forKey: key(profile)) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    /// Restores entries from a backup, keeping the newest `limit` of both journals without duplicates.
    static func merge(_ other: [Entry], profile: String = "default", defaults: UserDefaults = .standard) {
        let mine = entries(profile: profile, defaults: defaults)
        let extra = other.filter { !mine.contains($0) }
        save(Array((mine + extra).sorted { $0.date < $1.date }.suffix(limit)), profile: profile, defaults: defaults)
    }

    /// A value that must be finite and was not (NaN or infinity): replaces it with `fallback` and leaves a trace.
    static func finite(_ value: Double, fallback: Double = 0, _ detail: String) -> Double {
        guard value.isFinite else {
            record(.nonFiniteValue, detail)
            return fallback
        }
        return value
    }

    private static func save(_ all: [Entry], profile: String, defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key(profile)) }
    }
}
