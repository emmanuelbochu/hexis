import Foundation
import SwiftData

/// Where the training stands in its cycle (6 weeks by default): 5 training weeks (the first one a notch easier), then a deload week
/// (same loads, half the sets). A deload, an empty week or a new program restarts the cycle.
struct TrainingCycle: Equatable {
    var deloadStarts: [Date]
    /// Monday of the week the active program was loaded.
    var programStart: Date?
    /// When it was loaded.
    var programLoadedAt: Date?

    /// Training weeks before the deload week: 5 unless the program says otherwise (`trainingWeeks` of `Program.json`).
    static var trainingWeeks: Int { ProgramCatalog.trainingWeeks }

    func isDeload(_ date: Date) -> Bool {
        deloadStarts.contains { WeekReview.calendar.isDate($0, equalTo: date, toGranularity: .weekOfYear) }
    }

    /// Monday after the last deload week already over at `date` (nil when none is).
    func lastDeloadEnd(before date: Date) -> Date? {
        deloadStarts.map { WeekReview.weekStart(containing: $0, offset: 1) }.filter { $0 <= date }.max()
    }

    /// Training weeks before the week of `date`, one missed week tolerated (0 = this week restarts the cycle).
    func weeksBefore(_ date: Date, sessionDates: [Date]) -> Int {
        let weeks = Set(sessionDates.map { WeekReview.weekStart(containing: $0) })
        let deloads = Set(deloadStarts.map { WeekReview.weekStart(containing: $0) })
        var count = 0
        var missed = 0
        for offset in stride(from: -1, through: -26, by: -1) {
            let week = WeekReview.weekStart(containing: date, offset: offset)
            if week < (programStart ?? .distantPast) || deloads.contains(week) { break }
            if weeks.contains(week) {
                count += 1
                missed = 0
            } else {
                // One missed week (illness, trip) does not restart the cycle; two in a row do.
                missed += 1
                if missed >= 2 { break }
            }
        }
        return count
    }

    /// The first week of a cycle (`rampWeeks` of them) aims further from failure: the body gets back into it.
    func isRestartWeek(_ date: Date, sessionDates: [Date]) -> Bool {
        !isDeload(date) && weeksBefore(date, sessionDates: sessionDates) < ProgramCatalog.rampWeeks
    }

    static func load(context: ModelContext, defaults: UserDefaults = .standard) -> TrainingCycle {
        let starts = ((try? context.fetch(FetchDescriptor<DeloadWeek>())) ?? []).map(\.start)
        let loaded = defaults.object(forKey: ProgramSync.startKey) as? Date
        return TrainingCycle(deloadStarts: starts, programStart: loaded.map { WeekReview.weekStart(containing: $0) }, programLoadedAt: loaded)
    }
}
