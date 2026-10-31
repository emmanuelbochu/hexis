import Foundation
import Testing
@testable import HexisLogic

/// Hexis Elle's nudges: only when needed, spaced out more and more, never two in a day, never a canned or repeated line.
@Suite struct NudgeTests {
    private let calendar = WeekReview.calendar
    /// Wednesday 28 October 2026, noon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12)) ?? .now }
    private func ago(_ days: Int, hour: Int = 18) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func slots(_ dates: [Date], target: Int = 2) -> [NudgePlan.Slot] {
        NudgePlan.slots(sessionDates: dates, weeklyTarget: target, now: now, calendar: calendar)
    }

    /// Reopening the app re-plans: a slot already worded keeps its line (no AI request); a new moment or changed facts need one.
    @Test func plannedLinesAreReusedAndOnlyNewSlotsGoToTheAI() {
        let all = slots([ago(6)])
        let planned = Dictionary(all.dropFirst().map { (NudgeService.key($0), "ligne \($0.date)") }, uniquingKeysWith: { a, _ in a })
        let first = NudgeService.reuse(slots: all, planned: planned)
        #expect(first.missing == [all[0]] && first.kept.count == all.count - 1)
        // Same moment, other facts (a session was done meanwhile): worded again.
        var changed = all[1]
        changed.facts += " Une séance de plus."
        #expect(NudgeService.reuse(slots: [changed], planned: planned).missing == [changed])
        #expect(NudgeService.identifier(changed) == NudgeService.identifier(all[1]))
        // Nothing new: no request at all.
        #expect(NudgeService.reuse(slots: Array(all.dropFirst()), planned: planned).missing.isEmpty)
    }

    @Test func nothingWhenSheIsOnTrack() {
        // Two sessions this week (Monday, Tuesday): no reminder before the next week, nothing the day after a session either.
        let nextMonday = WeekReview.weekStart(containing: now, offset: 1)
        let all = slots([ago(2), ago(1)])
        #expect(all.allSatisfy { $0.date >= nextMonday })
        #expect(slots([ago(0, hour: 9)]).allSatisfy { $0.kind != .weekAtRisk || $0.date > now })
    }

    @Test func noNudgeBeforeFiveDaysWithoutASessionWhenTheWeekIsDone() {
        #expect(slots([ago(2), ago(1)]).filter { $0.date < WeekReview.weekStart(containing: now, offset: 1) }.isEmpty)
    }

    @Test func thursdayReminderOnlyWhileTheWeekIsOpen() {
        #expect(slots([ago(1)]).contains { $0.kind == .weekAtRisk })
        #expect(!slots([ago(2), ago(1)]).contains { $0.kind == .weekAtRisk })
    }

    @Test func absenceLadderCountsFromTheLastSession() {
        // Last session 6 days ago, the week open: the day-5 step is past, the next ones are day 8, 12…
        let days = slots([ago(6)]).filter { $0.kind == .absence }.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: ago(6)), to: calendar.startOfDay(for: $0.date)).day }
        #expect(days.first == 8)
    }

    @Test func neverTwoInADayAndNeverMoreThanTheCap() {
        let all = slots([ago(6)])
        let days = all.map { calendar.startOfDay(for: $0.date) }
        #expect(Set(days).count == days.count && all.count <= NudgePlan.maxSlots)
        #expect(all == all.sorted { $0.date < $1.date })
    }

    @Test func gapsWidenTheLongerSheStaysAway() {
        let days = slots([ago(6)]).filter { $0.kind == .absence }.map { calendar.startOfDay(for: $0.date) }
        let gaps = zip(days, days.dropFirst()).map { calendar.dateComponents([.day], from: $0, to: $1).day ?? 0 }
        #expect(gaps == gaps.sorted())
    }

    @Test func noSessionYetStillGetsAnEarlyNudge() {
        let first = slots([]).first { $0.kind == .absence }
        #expect(first?.facts == "Elle n'a pas encore fait sa première séance.")
    }

    @Test func hourFollowsWhenSheTrains() {
        #expect(NudgePlan.hour(sessionDates: [], calendar: calendar) == NudgePlan.defaultHour)
        #expect(NudgePlan.hour(sessionDates: [ago(3, hour: 18), ago(7, hour: 19), ago(10, hour: 18)], calendar: calendar) == 16)
        #expect(NudgePlan.hour(sessionDates: [ago(3, hour: 8)], calendar: calendar) == 9)
    }

    @Test func onlyCleanNewAILinesAreKeptNeverACannedOne() {
        let planned = slots([ago(6)])
        let line = "Ton programme t'attend, et il a des choses à te dire."
        let kept = NudgeService.texts(for: [planned[0]], generated: [line], recent: [])
        #expect(kept.first?.text == line)
        #expect(NudgeService.texts(for: [planned[0]], generated: [line], recent: [line]).isEmpty)
        #expect(NudgeService.texts(for: planned, generated: [], recent: []).isEmpty)
        let doubled = NudgeService.texts(for: Array(planned.prefix(2)), generated: [line, line], recent: [])
        #expect(doubled.count == 1)
    }

    @Test func coachingCardLinesAreDropped() {
        let planned = slots([ago(6)])
        for line in ["Prends ce moment pour toi, savoure la fierté de ton effort.", "Bravo pour ta séance, tu peux être fière.", "Un petit tour à la salle demain ?"] {
            let kept = NudgeService.texts(for: [planned[0]], generated: [line], recent: [])
            #expect(kept.isEmpty == (line != "Un petit tour à la salle demain ?"), "\(line)")
        }
    }
}
