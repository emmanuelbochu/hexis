import Foundation
import UserNotifications

/// Local notification fired when a rest ends while the app is in the background.
enum NotificationService {
    private static let restID = "rest-end"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func scheduleRestEnd(at date: Date, kind: RestTimer.Kind = .rest, next: String = "") {
        cancelRestEnd(kind)
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = kind == .rest ? "Repos terminé" : "\(next) : c'est l'heure"
        content.body = kind == .rest ? "Prochaine série." : "Retourne au batch cooking."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("rest_end.caf"))
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id(kind), content: content, trigger: trigger))
    }

    static func cancelRestEnd(_ kind: RestTimer.Kind = .rest) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id(kind)])
    }

    /// One notification per batch step, so several timers can run and each rings at its own end.
    static func scheduleBatchEnd(at date: Date, title: String) {
        cancelBatchEnd(title: title)
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(title) : c'est l'heure"
        content.body = "Retourne au batch cooking."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("rest_end.caf"))
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: batchID(title), content: content, trigger: trigger))
    }

    static func cancelBatchEnd(title: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [batchID(title)])
    }

    /// Drops every waiting batch notification except those of the timers still running (an old test, a cancelled batch).
    static func purgeBatchEnds(keeping titles: Set<String>) {
        let keep = Set(titles.map(batchID))
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix("batch-step-end") && !keep.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
    }

    private static func batchID(_ title: String) -> String { "batch-step-end-\(title)" }

    private static func id(_ kind: RestTimer.Kind) -> String { kind == .rest ? restID : "batch-step-end" }

    private static let shoppingID = "shopping-ready"

    /// Friday evening, once the cycle has flipped: the list for Saturday's shopping is ready (not announced for a holiday week).
    static func scheduleShoppingReady(now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [shoppingID])
        guard let when = PlanCycle.nextListReady(after: now), !FreePeriod.isHolidayCycle(PlanCycle.start(for: when.addingTimeInterval(60))) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Liste de courses prête"
        content.body = "Pour demain matin, à jour avec ton stock."
        let parts = PlanCycle.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: when)
        center.add(UNNotificationRequest(identifier: shoppingID, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
}
