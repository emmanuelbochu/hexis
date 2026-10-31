import Foundation
import UserNotifications

/// The free Apple profile of a development build lasts 7 days: tells on the iPhone when the app is about to stop opening.
/// The Mac refreshes the build by itself (`Tools/weekly_build.py`); this is the safety net when it could not.
enum ProfileExpiry {
    private static let id = "profile-expiry"
    /// How long before the expiry the reminder rings.
    private static let lead: TimeInterval = 36 * 3600

    /// Expiry date read from the provisioning profile embedded in the app (nil for a build without one).
    static func expiryDate(bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              start.lowerBound < end.upperBound,
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }

    /// Replaces the pending reminder with one for this build's expiry; a new install is one more launch away from re-arming it.
    static func scheduleReminder(now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let expiry = expiryDate() else { return }
        let interval = expiry.addingTimeInterval(-lead).timeIntervalSince(now)
        guard interval > 60 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Hexis expire bientôt"
        content.body = "Allume le Mac sur le même Wi-Fi : la mise à jour se fait seule."
        content.interruptionLevel = .passive
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
    }
}
