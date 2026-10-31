import Foundation
import SwiftData

/// Plans the deload week by itself when the advice is due this week (no tap needed); the sessions then keep their loads with half the sets.
enum AutoDeload {
    /// The deload advice from the history (the same one everywhere: home, analysis, auto-planning).
    @MainActor private static var cached: (key: String, advice: DeloadAdvice?)?

    /// The home screen asks several times per launch: the answer only changes with the sessions, the feelings, the planned
    /// deloads or the day, so it is worked out once per such state.
    @MainActor
    static func advice(in context: ModelContext, now: Date = .now) -> DeloadAdvice? {
        let sessionCount = (try? context.fetchCount(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? 0
        let feelingCount = (try? context.fetchCount(FetchDescriptor<ExerciseFeeling>())) ?? 0
        let deloadCount = (try? context.fetchCount(FetchDescriptor<DeloadWeek>())) ?? 0
        let key = "\(sessionCount)-\(feelingCount)-\(deloadCount)-\(Calendar.current.startOfDay(for: now).timeIntervalSince1970)"
        if let cached, cached.key == key { return cached.advice }
        let result = compute(in: context, now: now)
        cached = (key, result)
        return result
    }

    private static func compute(in context: ModelContext, now: Date) -> DeloadAdvice? {
        let since = Calendar.current.date(byAdding: .day, value: -120, to: now) ?? now
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "finished" }))) ?? []
        let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.kindRaw == "work" && $0.completedAt >= since }))) ?? []
        let feelings = (try? context.fetch(FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { $0.createdAt >= since }))) ?? []
        let cycle = TrainingCycle.load(context: context)

        let recentSince = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let recentIDs = Set(sessions.filter { $0.startedAt >= recentSince }.map(\.id))
        let efforts = sets.filter { recentIDs.contains($0.sessionID) && !cycle.isDeload($0.completedAt) }.compactMap { $0.rir.map { Double(10 - $0) } }
        let recentRPE = efforts.count >= 6 ? efforts.reduce(0, +) / Double(efforts.count) : nil
        let tiredSessions = Set(feelings.filter { $0.isSessionWide && $0.feeling == .tired && recentIDs.contains($0.sessionID) }.map(\.sessionID)).count

        return DeloadAdvisor.advice(
            now: now, sessionDates: sessions.map(\.startedAt), deloadStarts: cycle.deloadStarts,
            plateauCount: StagnationDetector.findings(sets: plateauSets(sets, cycle: cycle, now: now), feelings: feelings, cycle: cycle, now: now).count,
            recentRPE: recentRPE, tiredSessions: tiredSessions, programStart: cycle.programStart
        )
    }

    /// The sets a plateau is judged on to bring the deload forward: those after the last deload. A plateau that deload did not
    /// break is the exercise's own business (`SessionAdjuster`), not a reason for another deload 3 weeks later.
    static func plateauSets(_ sets: [SetLog], cycle: TrainingCycle, now: Date) -> [SetLog] {
        // Sets imported from before the app (Hevy) belong to another program: no plateau is read from them.
        let own = sets.filter { !HistorySeed.isImported($0.sessionID) }
        guard let end = cycle.lastDeloadEnd(before: now) else { return own }
        return own.filter { $0.completedAt >= end }
    }

    @MainActor
    static func planIfDue(in context: ModelContext, now: Date = .now) {
        guard let advice = advice(in: context, now: now), advice.weekStart <= WeekReview.weekStart(containing: now) else { return }
        context.insert(DeloadWeek(start: advice.weekStart, reason: advice.reason))
        context.saveReportingFailure()
    }
}
