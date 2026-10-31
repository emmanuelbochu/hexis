import Foundation

/// When this install was built, told discreetly on the home screen so an update (or a missing one) is seen at a glance.
enum BuildInfo {
    /// A build counts as « new » for this long.
    static let freshFor: TimeInterval = 36 * 3600

    /// The executable is rewritten by every build: its date is the version's.
    static let builtAt: Date? = {
        guard let url = Bundle.main.executableURL else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }()

    /// « Mise à jour il y a 3 h » for a fresh build, else « Version du 31 oct. à 14:20 ».
    static func label(built: Date, now: Date) -> (text: String, isFresh: Bool) {
        let age = now.timeIntervalSince(built)
        let locale = Locale(identifier: "fr_FR")
        if age >= 0, age < freshFor {
            let relative = RelativeDateTimeFormatter()
            relative.locale = locale
            relative.unitsStyle = .short
            return ("Mise à jour \(relative.localizedString(for: built, relativeTo: now))", true)
        }
        return ("Version du \(built.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(locale)))", false)
    }
}
