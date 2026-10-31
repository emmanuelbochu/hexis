import Foundation
import Testing
@testable import HexisLogic

private let calendar = WeekReview.calendar

private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 18) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}

/// One session in each of the given weeks, counted back from the Monday `monday` (0 = that week, -1 = the one before…).
private func sessions(weeks: [Int], from monday: Date) -> [Date] {
    weeks.map { calendar.date(byAdding: .weekOfYear, value: $0, to: monday)!.addingTimeInterval(86_400 * 2) }
}

@Suite struct CycleTests {
    /// Monday 2026-11-09 and 2026-11-16 (outside the school holidays).
    let monday = day(2026, 11, 9, hour: 0)

    @Test func deloadWeekAcrossNewYearIsRecognised() {
        let cycle = TrainingCycle(deloadStarts: [day(2026, 12, 28, hour: 0)], programStart: nil, programLoadedAt: nil)
        #expect(cycle.isDeload(day(2026, 12, 30)))
        #expect(cycle.isDeload(day(2027, 1, 3)))
        #expect(!cycle.isDeload(day(2027, 1, 4)))
        #expect(!cycle.isDeload(day(2026, 12, 27)))
    }

    /// A plateau the last deload did not break must not bring the next one forward: only what follows that deload counts.
    @Test func plateauBeforeTheLastDeloadIsNotJudgedAgain() {
        let deload = day(2026, 11, 9, hour: 0)
        let cycle = TrainingCycle(deloadStarts: [deload], programStart: nil, programLoadedAt: nil)
        #expect(cycle.lastDeloadEnd(before: day(2026, 11, 12)) == nil)
        #expect(cycle.lastDeloadEnd(before: day(2026, 12, 1)) == day(2026, 11, 16, hour: 0))
        // The same plateau, 4 weekly sessions before the deload and 2 after: judged on the 2 after, it is no plateau.
        let bench = UUID()
        let dates = [-28, -21, -14, -7, 14, 21].map { deload.addingTimeInterval(Double($0) * 86_400 + 64_800) }
        let sets = dates.map { SetLog(sessionID: UUID(), exerciseID: bench, gymID: nil, index: 0, weight: 40, reps: 8, completedAt: $0) }
        let now = day(2026, 12, 3)
        #expect(!StagnationDetector.findings(sets: sets, feelings: [], cycle: cycle, now: now).isEmpty)
        #expect(StagnationDetector.findings(sets: AutoDeload.plateauSets(sets, cycle: cycle, now: now), feelings: [], cycle: cycle, now: now).isEmpty)
    }

    @Test func sameWeekNumberTwoYearsApartIsNotADeload() {
        let cycle = TrainingCycle(deloadStarts: [day(2026, 11, 9, hour: 0)], programStart: nil, programLoadedAt: nil)
        #expect(!cycle.isDeload(day(2027, 11, 10)))
    }

    @Test func fiveTrainingWeeksMakeTheDeloadDueNextWeek() {
        // Weeks -5…-1 trained, this week not started: due now.
        let dates = sessions(weeks: [-5, -4, -3, -2, -1], from: monday)
        let advice = DeloadAdvisor.advice(now: monday.addingTimeInterval(86_400), sessionDates: dates, deloadStarts: [], plateauCount: 0, holidays: [], dueAfterWeeks: 5)
        #expect(advice?.weekStart == monday)
    }

    @Test func weekAlreadyStartedPushesTheDeloadToNextWeek() {
        let dates = sessions(weeks: [-4, -3, -2, -1, 0], from: monday)
        let advice = DeloadAdvisor.advice(now: monday.addingTimeInterval(3 * 86_400), sessionDates: dates, deloadStarts: [], plateauCount: 0, holidays: [], dueAfterWeeks: 5)
        #expect(advice?.weekStart == calendar.date(byAdding: .weekOfYear, value: 1, to: monday))
    }

    @Test func fourWeeksWithoutStrainIsNotDue() {
        let dates = sessions(weeks: [-4, -3, -2, -1], from: monday)
        #expect(DeloadAdvisor.advice(now: monday, sessionDates: dates, deloadStarts: [], plateauCount: 0, holidays: [], dueAfterWeeks: 5) == nil)
    }

    @Test func threeWeeksWithTwoPlateausIsDue() {
        let dates = sessions(weeks: [-3, -2, -1], from: monday)
        #expect(DeloadAdvisor.advice(now: monday, sessionDates: dates, deloadStarts: [], plateauCount: 2, holidays: [], dueAfterWeeks: 5) != nil)
    }

    @Test func oneMissedWeekKeepsTheCountTwoRestartIt() {
        let one = sessions(weeks: [-5, -4, -2, -1], from: monday)
        #expect(DeloadAdvisor.trainingWeeks(sessionDates: one, deloadStarts: [], now: monday) == 4)
        let two = sessions(weeks: [-6, -5, -4, -1], from: monday)
        #expect(DeloadAdvisor.trainingWeeks(sessionDates: two, deloadStarts: [], now: monday) == 1)
    }

    @Test func returningAfterThreeWeeksOffRestartsTheCycle() {
        let dates = sessions(weeks: [-8, -7, -6, -5, -4], from: monday)
        #expect(DeloadAdvisor.advice(now: monday, sessionDates: dates, deloadStarts: [], plateauCount: 3, holidays: [], dueAfterWeeks: 5) == nil)
        let cycle = TrainingCycle(deloadStarts: [], programStart: nil, programLoadedAt: nil)
        #expect(cycle.isRestartWeek(monday, sessionDates: dates))
    }

    @Test func weekAfterADeloadIsARestartWeekEvenWithAMissedWeek() {
        let deload = calendar.date(byAdding: .weekOfYear, value: -2, to: monday)!
        let cycle = TrainingCycle(deloadStarts: [deload], programStart: nil, programLoadedAt: nil)
        let dates = sessions(weeks: [-8, -7, -6, -5, -4, -3, -2], from: monday)
        #expect(cycle.isRestartWeek(monday, sessionDates: dates))
        #expect(!cycle.isRestartWeek(deload, sessionDates: dates))
    }

    @Test func plannedDeloadIsNeverPlannedTwice() {
        let dates = sessions(weeks: [-5, -4, -3, -2, -1], from: monday)
        let planned = [monday]
        #expect(DeloadAdvisor.advice(now: monday, sessionDates: dates, deloadStarts: planned, plateauCount: 3, holidays: [], dueAfterWeeks: 5) == nil)
    }

    @Test func overdueDeloadDoesNotWaitForADistantHoliday() {
        // 7 weeks trained, a holiday 4 weeks away: the deload must not drift to it.
        let dates = sessions(weeks: [-7, -6, -5, -4, -3, -2, -1], from: monday)
        let far = calendar.date(byAdding: .weekOfYear, value: 4, to: monday)!
        let holiday = SchoolHoliday(name: "test", start: far, end: calendar.date(byAdding: .day, value: 6, to: far)!)
        let advice = DeloadAdvisor.advice(now: monday, sessionDates: dates, deloadStarts: [], plateauCount: 0, holidays: [holiday], dueAfterWeeks: 5)
        #expect(advice?.weekStart == monday)
    }
}
