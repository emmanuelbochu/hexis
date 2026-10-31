import Foundation
import SwiftData

/// Tells when the plan is not being lived (school holidays, a stretch without logging): the stock, the weight verdict and the
/// shopping list then stop guessing from the plan, so nothing is falsified and the bulk is not touched. It comes from the
/// calendar (the school holidays) and from the behaviour (3 days in a row with at most one slot logged), nothing to switch on.
enum FreePeriod {
    static let runLength = 3
    /// Days of calm after a free stretch before the scale is trusted again to move the plan.
    static let settleDays = 7

    struct Status: Equatable {
        var text: String
    }

    /// The holiday of the calendar that contains `day`.
    static func holiday(on day: Date, holidays: [SchoolHoliday] = SchoolHoliday.current, calendar: Calendar = .current) -> SchoolHoliday? {
        let start = calendar.startOfDay(for: day)
        return holidays.first { start >= calendar.startOfDay(for: $0.start) && start <= calendar.startOfDay(for: $0.end) }
    }

    /// A cycle (Monday) that is mostly holiday: its list is shown as indicative and no « list ready » notification is sent.
    static func isHolidayCycle(_ cycle: Date, holidays: [SchoolHoliday] = SchoolHoliday.current) -> Bool {
        holidays.contains { $0.overlapDays(weekStarting: cycle) >= 4 }
    }

    /// Free days among the given days (slots logged per day): holiday days, and runs of `runLength`+ days with at most one slot.
    static func freeDays(_ slotCounts: [Date: Int], holidays: [SchoolHoliday] = SchoolHoliday.current, calendar: Calendar = .current) -> Set<Date> {
        var result = Set(slotCounts.keys.filter { holiday(on: $0, holidays: holidays, calendar: calendar) != nil })
        var run: [Date] = []
        for day in slotCounts.keys.sorted() {
            if let last = run.last, calendar.date(byAdding: .day, value: 1, to: last) != day { run = [] }
            if (slotCounts[day] ?? 0) <= 1 {
                run.append(day)
                if run.count >= runLength { result.formUnion(run) }
            } else {
                run = []
            }
        }
        return result
    }

    /// Slots accounted for on each day of `[from, to)`: a plan meal validated, or any food logged in that slot.
    static func loggedSlots(from: Date, to: Date, meals: [PlanMeal], in context: ModelContext, calendar: Calendar = .current) -> [Date: Set<String>] {
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.date >= from && $0.date < to }))) ?? []
        let logs = (try? context.fetch(FetchDescriptor<PlanMealLog>(predicate: #Predicate { $0.day >= from && $0.day < to }))) ?? []
        let planned = Dictionary(meals.map { ($0.id, $0.slotRaw) }, uniquingKeysWith: { first, _ in first })
        var result: [Date: Set<String>] = [:]
        var day = calendar.startOfDay(for: from)
        while day < to {
            result[day] = []
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? to
        }
        for entry in entries { result[calendar.startOfDay(for: entry.date), default: []].insert(entry.mealRaw) }
        for log in logs { if let slot = planned[log.planMealID] { result[calendar.startOfDay(for: log.day), default: []].insert(slot) } }
        return result
    }

    /// Free days among the `lookback` days before today, read from the store.
    private static func recentFreeDays(in context: ModelContext, now: Date, lookback: Int, holidays: [SchoolHoliday], calendar: Calendar) -> Set<Date> {
        let today = calendar.startOfDay(for: now)
        guard let from = calendar.date(byAdding: .day, value: -lookback, to: today) else { return [] }
        let meals = (try? context.fetch(FetchDescriptor<PlanMeal>())) ?? []
        let logged = loggedSlots(from: from, to: today, meals: meals, in: context, calendar: calendar)
        return freeDays(logged.mapValues(\.count), holidays: holidays, calendar: calendar)
    }

    /// What to say on the nutrition screen while the plan is not lived, nil in ordinary life.
    static func status(in context: ModelContext, now: Date = .now, holidays: [SchoolHoliday] = SchoolHoliday.current, calendar: Calendar = .current) -> Status? {
        if let holiday = holiday(on: now, holidays: holidays, calendar: calendar) {
            return Status(text: "\(holiday.name.prefix(1).uppercased() + holiday.name.dropFirst()) · suivi en pause")
        }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              recentFreeDays(in: context, now: now, lookback: 6, holidays: holidays, calendar: calendar).contains(yesterday)
        else { return nil }
        return Status(text: "Semaine libre · suivi en pause")
    }

    /// True during a free stretch and for `settleDays` after it: the weight of those weeks says nothing about the plan.
    static func pausesAdjustment(in context: ModelContext, now: Date = .now, holidays: [SchoolHoliday] = SchoolHoliday.current, calendar: Calendar = .current) -> Bool {
        holiday(on: now, holidays: holidays, calendar: calendar) != nil
            || !recentFreeDays(in: context, now: now, lookback: settleDays, holidays: holidays, calendar: calendar).isEmpty
    }
}
