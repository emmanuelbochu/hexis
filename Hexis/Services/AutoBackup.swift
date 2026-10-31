import Foundation
import SwiftData

/// Writes a JSON snapshot in the app's Documents folder (visible in Files), keeping the latest few.
nonisolated enum AutoBackup {
    private static let keep = 20

    @discardableResult
    static func save(from context: ModelContext) -> URL? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? BackupService.exportData(from: context)
        else { return nil }
        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "")
        let url = dir.appendingPathComponent("hexis-auto-\(stamp).json")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        prune(in: dir)
        return url
    }

    /// Same snapshot, read and written off the main thread (a growing history made the encoding noticeable).
    /// The context is saved first so the background one sees everything.
    @MainActor
    static func saveInBackground(from context: ModelContext) {
        context.saveReportingFailure()
        let container = context.container
        Task.detached(priority: .utility) { save(from: ModelContext(container)) }
    }

    /// Daily safety net: a snapshot at launch when the last one is older than 20 hours.
    @MainActor
    static func saveIfStale(from context: ModelContext, now: Date = .now) {
        if let last = lastBackupDate(), now.timeIntervalSince(last) < 20 * 3600 { return }
        saveInBackground(from: context)
    }

    /// A database that came back empty (reset after a failure, new install over kept files) takes the latest snapshot back by itself.
    /// Must run before anything seeds data.
    @MainActor
    static func restoreIfEmpty(in context: ModelContext) {
        let empty = ((try? context.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 1) == 0
            && ((try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 1) == 0
            && ((try? context.fetchCount(FetchDescriptor<Ingredient>())) ?? 1) == 0
        guard empty, let file = latestFile(), let data = try? Data(contentsOf: file) else { return }
        do { try BackupService.restore(data, into: context, snapshotFirst: false) } catch {
            Diagnostics.record(.backupUnreadable, error.localizedDescription)
        }
    }

    private static let reminderKey = "backupReminderOn"

    /// The weekly nudge to copy the latest snapshot off the phone (Files, AirDrop): once a week, and only once there is history.
    static func reminderDue(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard latestFile() != nil else { return false }
        guard let last = defaults.object(forKey: reminderKey) as? Date else {
            defaults.set(now, forKey: reminderKey)
            return false
        }
        return now.timeIntervalSince(last) >= 7 * 86_400
    }

    static func markReminded(now: Date = .now, defaults: UserDefaults = .standard) {
        defaults.set(now, forKey: reminderKey)
    }

    static func latestFile() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first.flatMap { files(in: $0).first }
    }

    static func lastBackupDate() -> Date? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return files(in: dir).first.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
    }

    private static func files(in dir: URL) -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.lastPathComponent.hasPrefix("hexis-auto-") }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func prune(in dir: URL) {
        files(in: dir).dropFirst(keep).forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
