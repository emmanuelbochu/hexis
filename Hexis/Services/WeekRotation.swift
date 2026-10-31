import Foundation

/// Which session the home screen proposes. A usual week follows the program order (`TemplatePicker`). When the week can no
/// longer hold its usual sessions at one every other day from today, the rest of the week switches by itself to the
/// 3-session variant of `Program.json` (`shortWeek`): sessions already done stand for the ones they cover (`replaces`).
/// Nothing to switch on or off: a 3-session-only session done this week keeps the week short, a full week stays usual.
struct WeekRotation: Equatable {
    struct Template: Equatable {
        var id: UUID
        var order: Int
        var name: String
        /// Usual sessions it stands in for; non-empty = 3-session week only.
        var replaces: [String] = []
    }

    var next: UUID?
    /// The week runs on the 3-session variant.
    var short: Bool
    /// 3-session-week sessions still to do, in order.
    var remaining: [String]
    /// Usual-week catch-up when the file has no variant.
    var plan: WeekPlan?

    static func make(
        templates: [Template], shortWeek: [String], sessions: [(templateID: UUID?, date: Date)],
        now: Date = .now, calendar: Calendar = WeekReview.calendar
    ) -> WeekRotation {
        let usual = templates.filter(\.replaces.isEmpty).sorted { $0.order < $1.order }
        let byID = Dictionary(templates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let monday = WeekReview.weekStart(containing: now)
        let thisWeek = sessions.filter { $0.date >= monday && $0.date <= now }
        let done = Set(thisWeek.compactMap { $0.templateID.flatMap { byID[$0]?.name } })

        let elapsed = calendar.dateComponents([.day], from: monday, to: calendar.startOfDay(for: now)).day ?? 0
        let daysLeft = max(7 - elapsed, 1)
        // One session every other day from today: Monday holds 4, Thursday 2, Saturday 1.
        let capacity = (daysLeft + 1) / 2
        let needed = usual.count - thisWeek.count
        let shortOnlyDone = templates.contains { !$0.replaces.isEmpty && done.contains($0.name) }
        let slots = shortWeek.compactMap { name in templates.first { $0.name == name } }

        if !slots.isEmpty, shortOnlyDone || needed > capacity {
            let remaining = slots.filter { !done.contains($0.name) && !$0.replaces.contains(where: done.contains) }
            if let first = remaining.first {
                return WeekRotation(next: first.id, short: true, remaining: remaining.map(\.name))
            }
        }
        let usualIDs = Set(usual.map(\.id))
        let usualSessions = sessions.filter { $0.templateID.map(usualIDs.contains) ?? false }
        let plan = slots.isEmpty
            ? WeekPlan.make(templates: usual.map { ($0.id, $0.order) }, sessions: usualSessions, now: now)
            : nil
        let lastDone = usualSessions.max { $0.date < $1.date }?.templateID
        let next = plan?.queue.first ?? TemplatePicker.pick(from: usual.map { ($0.id, $0.order) }, lastDone: lastDone)
        return WeekRotation(next: next, short: false, remaining: [], plan: plan)
    }

    /// What the app tells about the week; nil for a usual week on track.
    func note(names: [UUID: String]) -> SessionAdjustments.Note? {
        guard short else { return plan?.note(names: names) }
        return .init(
            id: "week-plan", symbol: "calendar.badge.clock",
            text: "Semaine à 3 séances : reste \(remaining.joined(separator: ", ")). Priorités gardées, jambes et bras en entretien."
        )
    }
}

extension WeekRotation {
    /// Over the stored templates, with the variant described by `Program.json`.
    static func make(templates: [WorkoutTemplate], sessions: [(templateID: UUID?, date: Date)], now: Date = .now) -> WeekRotation {
        make(
            templates: templates.map { Template(id: $0.id, order: $0.order, name: $0.name, replaces: ProgramCatalog.replaces($0.name)) },
            shortWeek: ProgramCatalog.shortWeek, sessions: sessions, now: now
        )
    }
}
