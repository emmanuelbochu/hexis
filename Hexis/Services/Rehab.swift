import Foundation
import SwiftData

/// Rehab in phases (`Program.json` → `rehab`): a clean week with at least 2 rehab sessions (the plan asks for 3, 2 in a
/// 3-session week) moves it one week on, a week with « Gêne » on a rehab or calf exercise sends it one week back (the
/// plan's rule: ≤ 3/10 during, nothing more the next morning), a week with a single session holds. After the last
/// phase the rehab blocks disappear from the sessions. Counted from the first rehab set, so a program edit never resets it.
enum Rehab {
    struct Status: Equatable {
        /// 0-based phase.
        var phase: Int
        /// 1-based week of the whole rehab.
        var week: Int
        var totalWeeks: Int
        var done: Bool
        /// The last rehab week had a pain flag.
        var setBack: Bool
    }

    struct Week: Equatable {
        var sessions: Int
        var pain: Bool
    }

    /// Sessions a week needs to move the rehab on.
    static let sessionsPerWeek = 2

    /// `weeks` are the finished weeks with rehab sets, oldest first (the running week is not judged yet).
    static func status(weeks: [Week], weeksPerPhase: Int, phases: Int) -> Status {
        var credit = 0
        for week in weeks {
            if week.pain { credit = max(0, credit - 1) } else if week.sessions >= sessionsPerWeek { credit += 1 }
        }
        let total = max(weeksPerPhase * phases, 1)
        return Status(
            phase: min(credit / max(weeksPerPhase, 1), max(phases - 1, 0)), week: min(credit + 1, total), totalWeeks: total,
            done: credit >= total, setBack: weeks.last?.pain ?? false
        )
    }

    /// The rehab slot (e.g. "mollet") a stored block stands for, from the names of its exercises.
    static func slot(of names: [String], in rehab: ProgramSpec.Rehab) -> String? {
        guard let first = names.first?.lowercased() else { return nil }
        for phase in rehab.phases {
            for (slot, exercises) in phase where exercises.contains(where: { $0.name.lowercased() == first }) { return slot }
        }
        return nil
    }

    /// Reads the whole rehab history (pain on a calf machine counts too: same calf).
    static func load(context: ModelContext, now: Date = .now) -> Status? {
        guard let rehab = ProgramCatalog.rehab else { return nil }
        let names = Set(ProgramCatalog.rehabExercises.map { $0.name.lowercased() })
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        // Rehab exercises of an older version of the file still count: a new rehab never restarts the weeks done.
        let ids = all.filter { names.contains($0.name.lowercased()) || $0.muscleGroup == "Réhab" }.map(\.id)
        let calfIDs = all.filter { names.contains($0.name.lowercased()) || $0.muscleGroup == "Réhab" || $0.muscleGroup == "Mollets" }.map(\.id)
        let current = WeekReview.weekStart(containing: now)
        let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { ids.contains($0.exerciseID) }))) ?? []
        guard let first = sets.map(\.completedAt).min() else {
            return status(weeks: [], weeksPerPhase: rehab.weeksPerPhase, phases: rehab.phases.count)
        }
        let feelings = (try? context.fetch(FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { calfIDs.contains($0.exerciseID) && $0.createdAt >= first }))) ?? []
        let painWeeks = Set(feelings.filter { $0.feeling == .pain }.map { WeekReview.weekStart(containing: $0.createdAt) })
        let sessions = Dictionary(grouping: sets, by: { WeekReview.weekStart(containing: $0.completedAt) }).mapValues { Set($0.map(\.sessionID)).count }
        let weeks = Set(sessions.keys).union(painWeeks).filter { $0 >= WeekReview.weekStart(containing: first) && $0 < current }.sorted()
        return status(weeks: weeks.map { Week(sessions: sessions[$0] ?? 0, pain: painWeeks.contains($0)) },
                      weeksPerPhase: rehab.weeksPerPhase, phases: rehab.phases.count)
    }

    /// What the app tells about the rehab on the home screen.
    static func note(_ status: Status, name: String) -> SessionAdjustments.Note? {
        guard !status.done else { return nil }
        let back = status.setBack ? " Gêne la semaine dernière : une semaine en arrière." : ""
        return .init(
            id: "rehab", symbol: "bandage",
            text: "\(name) : phase \(status.phase + 1), semaine \(status.week)/\(status.totalWeeks).\(back)"
        )
    }
}
