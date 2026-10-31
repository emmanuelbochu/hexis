import CoreLocation
import Foundation
import SwiftData

// macOS stand-ins for the services bound to the iPhone (sound, notifications, Live Activity):
// the logic tests and the simulator run the real view model without touching the device.
enum SoundService {
    enum Cue: String, CaseIterable {
        case setDone = "set_done", exerciseDone = "exercise_done", restEnd = "rest_end", sessionStart = "session_start"
        case sessionEnd = "session_end", record, mealDone = "meal_done"
    }
    static func prepare() {}
    static func play(_ cue: Cue) {}
    static func restEnded() {}
    static func timerEnded() {}
}

enum NotificationService {
    static func requestAuthorization() {}
    static func scheduleRestEnd(at date: Date, kind: RestTimer.Kind = .rest, next: String = "") {}
    static func cancelRestEnd(_ kind: RestTimer.Kind = .rest) {}
    static func scheduleBatchEnd(at date: Date, title: String) {}
    static func cancelBatchEnd(title: String) {}
    static func purgeBatchEnds(keeping titles: Set<String>) {}
}

enum RestActivity {
    static func show(until date: Date, next: String, title: String? = nil) {}
    static func end() {}
}

/// No GPS on the Mac: the position is unknown (or the one a test sets), so only the idle time closes a forgotten session.
final class LocationService {
    var isDenied = false
    var position: CLLocation?
    func currentLocation() async -> CLLocation? { position }
}

/// Snapshots would land in the Mac's Documents folder: none during tests.
nonisolated enum AutoBackup {
    @discardableResult static func save(from context: ModelContext) -> URL? { nil }
    static func saveInBackground(from context: ModelContext) {}
    static func saveIfStale(from context: ModelContext, now: Date = .now) {}
    static func restoreIfEmpty(in context: ModelContext) {}
    static func reminderDue(now: Date = .now, defaults: UserDefaults = .standard) -> Bool { false }
    static func markReminded(now: Date = .now, defaults: UserDefaults = .standard) {}
    static func latestFile() -> URL? { nil }
    static func lastBackupDate() -> Date? { nil }
}
