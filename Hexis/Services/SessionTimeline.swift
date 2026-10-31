import Foundation

/// The real course of one session read from the time each set was validated: order, time per exercise, rests, pauses.
struct SessionTimeline {
    /// What the program prescribes, to compare with what really happened.
    struct Plan {
        var rest: [UUID: Int] = [:]
        var supersets: Set<UUID> = []
        /// Exercises in program order.
        var order: [UUID] = []
    }

    struct Entry: Identifiable {
        var exerciseID: UUID
        /// 1-based place in the order the exercises were really done.
        var order: Int
        var firstAt: Date
        var lastAt: Date
        var workSets: Int
        /// Extra seconds per set compared with the prescribed rest (nil in supersets or without a plan).
        var overrun: [TimeInterval]
        var restSeconds: [TimeInterval]
        var plannedRest: Int?
        var movedFromProgram: Bool

        var id: UUID { exerciseID }
        var span: TimeInterval { lastAt.timeIntervalSince(firstAt) }
        var medianRest: TimeInterval? { restSeconds.isEmpty ? nil : restSeconds.sorted()[restSeconds.count / 2] }
    }

    /// Gaps longer than this are pauses (machine taken, phone, chat), not rests.
    static let pauseThreshold: TimeInterval = 8 * 60
    /// Rough time to perform one rep, to tell the rest from the set itself.
    private static let secondsPerRep: TimeInterval = 3.5

    var entries: [Entry]
    var pauseTotal: TimeInterval
    var isReliable: Bool

    init(sets: [SetLog], plan: Plan = Plan()) {
        let work = sets.filter { $0.kind == .work }.sorted { $0.completedAt < $1.completedAt }
        isReliable = Self.looksRecorded(work)
        var firstSeen: [UUID] = []
        for set in work where !firstSeen.contains(set.exerciseID) { firstSeen.append(set.exerciseID) }
        let programRank = plan.order.filter(firstSeen.contains)
        var pauses: TimeInterval = 0

        entries = firstSeen.enumerated().map { place, id in
            let own = work.filter { $0.exerciseID == id }
            var rests: [TimeInterval] = [], overruns: [TimeInterval] = []
            let planned = plan.rest[id]
            for (previous, next) in zip(own, own.dropFirst()) {
                // Left then right side of one set: no rest in between.
                if previous.side != nil, previous.side != next.side { continue }
                let gap = next.completedAt.timeIntervalSince(previous.completedAt)
                if gap > Self.pauseThreshold { pauses += gap; continue }
                rests.append(gap)
                if let planned, !plan.supersets.contains(id) {
                    overruns.append(gap - Double(planned) - Double(next.reps) * Self.secondsPerRep)
                }
            }
            return Entry(
                exerciseID: id, order: place + 1, firstAt: own.first?.completedAt ?? .now, lastAt: own.last?.completedAt ?? .now,
                workSets: own.count, overrun: overruns, restSeconds: rests, plannedRest: planned,
                movedFromProgram: programRank.firstIndex(of: id).map { $0 != place } ?? false
            )
        }
        pauseTotal = pauses
    }

    /// Sets typed in later (or imported) have evenly spaced or identical times: not a real timeline.
    private static func looksRecorded(_ sets: [SetLog]) -> Bool {
        guard sets.count >= 4 else { return false }
        let gaps = zip(sets, sets.dropFirst()).map { $1.completedAt.timeIntervalSince($0.completedAt) }
        let evenly = gaps.filter { abs($0 - gaps[0]) < 1 }.count
        return Double(evenly) / Double(gaps.count) < 0.8
    }

    /// Exercises whose real place differs from the program order.
    var movedCount: Int { entries.filter(\.movedFromProgram).count }
}
