import Foundation

/// A notification the app wants to send: what, when, said how. Every one goes through `NotificationPolicy` before it is scheduled.
struct Notice: Identifiable, Equatable {
    enum Kind: String {
        /// Real figures of the week, and a lighter week coming (his app).
        case review
        /// Her week is still open on Thursday.
        case weekAtRisk
        /// A while without a session.
        case absence

        /// Who wins when two compete for the same day or the weekly cap.
        var priority: Int {
            switch self {
            case .review: 3
            case .weekAtRisk: 2
            case .absence: 1
            }
        }
    }

    var kind: Kind
    var date: Date
    var title: String
    var body: String

    var id: String { "\(NotificationPolicy.prefix)\(kind.rawValue).\(Int(date.timeIntervalSince1970))" }
}

/// The one gatekeeper of the app's own notifications (timers and the Friday list are functional and stay outside): a phone that
/// buzzes too often is muted for good, so few messages, spaced out, never at night, the most useful first.
enum NotificationPolicy {
    /// Every notification this policy owns starts with it, so the app can tell its own from the timers' and clean up after itself.
    static let prefix = "hx."
    static let maxPerWeek = 3
    static let minGap: TimeInterval = 20 * 3600
    /// Hours (included) in which a notification may ring.
    static let allowedHours = 9...20

    static func apply(_ candidates: [Notice], now: Date = .now, calendar: Calendar = WeekReview.calendar) -> [Notice] {
        var kept: [Notice] = []
        let usable = candidates.filter { $0.date > now && allowedHours.contains(calendar.component(.hour, from: $0.date)) }
        for notice in usable.sorted(by: { ($1.kind.priority, $0.date) < ($0.kind.priority, $1.date) }) {
            let week = calendar.dateInterval(of: .weekOfYear, for: notice.date)
            let sameWeek = kept.filter { week?.contains($0.date) == true }.count
            let tooClose = kept.contains { abs($0.date.timeIntervalSince(notice.date)) < minGap || calendar.isDate($0.date, inSameDayAs: notice.date) }
            if sameWeek < maxPerWeek, !tooClose { kept.append(notice) }
        }
        return kept.sorted { $0.date < $1.date }
    }
}
