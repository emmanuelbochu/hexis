import Foundation
import SwiftData
import UserNotifications

/// The single place where the app's own notifications are planned (timers and the Friday shopping list are functional and
/// stay in `NotificationService`). It asks each edition for what it would like to say (his figures: `PerfNotices`; her words:
/// `NudgeService`), lets `NotificationPolicy` keep the few that are worth it, then makes the phone match: what is waiting and no
/// longer wanted goes, what is new comes in, a line whose text changed is replaced. Run again on every opening and after each
/// session, which is the only moment the facts move: nothing can be stale, whatever the app was doing when it was closed.
enum NotificationHub {
    private static let bodiesKey = "hubBodies"
    @MainActor private static var refreshing = false

    /// Identifiers of earlier versions, cleaned once found.
    private static func isLegacy(_ id: String) -> Bool { id.hasPrefix("nudge-") || id == "batch-step-end" }

    @MainActor static func refresh(in context: ModelContext, now: Date = .now, defaults: UserDefaults = .standard) async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: pending.filter(isLegacy).sorted())

        let candidates = Edition.isElle
            ? await NudgeService.notices(in: context, now: now, pending: pending, defaults: defaults)
            : PerfNotices.candidates(snapshot(in: context, now: now))
        let kept = NotificationPolicy.apply(candidates, now: now)

        let owned = pending.filter { $0.hasPrefix(NotificationPolicy.prefix) }
        let wanted = Set(kept.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers: owned.subtracting(wanted).sorted())
        let known = defaults.dictionary(forKey: bodiesKey) as? [String: String] ?? [:]
        for notice in kept where !(owned.contains(notice.id) && known[notice.id] == notice.body) {
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.body = notice.body
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notice.date)
            try? await center.add(UNNotificationRequest(identifier: notice.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
        defaults.set(Dictionary(kept.map { ($0.id, $0.body) }, uniquingKeysWith: { first, _ in first }), forKey: bodiesKey)
    }

    /// What his review needs: the sessions, this week and the one before, the lighter week due next.
    @MainActor private static func snapshot(in context: ModelContext, now: Date) -> PerfNotices.Snapshot {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? []
        let program = (try? context.fetch(FetchDescriptor<Program>(predicate: #Predicate { $0.isActive })))?.first
        let target = program.map { ProgramCatalog.usualWeek($0.templates).count } ?? 4
        let thisStart = WeekReview.weekStart(containing: now)
        let previousStart = WeekReview.weekStart(containing: now, offset: -1)
        var review: (WeekReview?, WeekReview?) = (nil, nil)
        if sessions.contains(where: { $0.startedAt >= thisStart }) {
            let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.kindRaw == "work" }))) ?? []
            let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let loads = LoadResolver(loads: (try? context.fetch(FetchDescriptor<ExerciseLoad>())) ?? [], exercises: exercises)
            review = (
                WeekReview(start: thisStart, sessions: sessions, sets: sets, exercises: byID, loads: loads),
                WeekReview(start: previousStart, sessions: sessions, sets: sets, exercises: byID, loads: loads)
            )
        }
        return PerfNotices.Snapshot(
            now: now, sessionDates: sessions.map(\.startedAt), weeklyTarget: target, thisWeek: review.0, previousWeek: review.1,
            deloadWeekStart: AutoDeload.advice(in: context, now: now)?.weekStart
        )
    }
}
