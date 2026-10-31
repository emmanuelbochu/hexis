import CoreLocation
import Foundation
import SwiftData

/// Ends a session by itself when it was left open: far from the gym for a while, or untouched for hours.
enum SessionCloser {
    enum Decision: Equatable {
        case keep
        /// Closed at the time of the last set (the figures stay true).
        case finish(at: Date)
        /// No set was ever done: nothing to keep.
        case discard
    }

    /// Time away from the gym (since the last set) before the session counts as over.
    static let awayAfter: TimeInterval = 20 * 60
    /// Without any position, a session untouched for this long is over.
    static let idleAfter: TimeInterval = 4 * 3600
    /// Margin on top of the gym's radius, so that a poor GPS fix at its edge does not end a session.
    static let margin = 100.0

    static func decide(startedAt: Date, lastSetAt: Date?, now: Date, outsideGym: Bool) -> Decision {
        let idle = now.timeIntervalSince(lastSetAt ?? startedAt)
        guard idle >= idleAfter || (outsideGym && idle >= awayAfter) else { return .keep }
        return lastSetAt.map { .finish(at: $0) } ?? .discard
    }

    /// One pass at a time: the launch and the return to the foreground can both ask for it.
    @MainActor private static var isRunning = false

    /// Checks the open sessions (one in practice) and closes the ones that are over; returns the ids closed.
    @MainActor @discardableResult
    static func run(in context: ModelContext, location: LocationService, now: Date = .now) async -> Set<UUID> {
        guard !isRunning else { return [] }
        isRunning = true
        defer { isRunning = false }
        let open = (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == "inProgress" }))) ?? []
        // Nothing open: a rest left from an earlier session (app killed mid-rest…) must not ring.
        guard !open.isEmpty else { stopRest(); return [] }
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        let here = await location.currentLocation()
        var closed: Set<UUID> = []
        for session in open {
            let id = session.id
            // The session may have been ended by hand while the position was being read.
            guard session.state == .inProgress else { continue }
            var lastSet = FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == id }, sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
            lastSet.fetchLimit = 1
            let last = (try? context.fetch(lastSet))?.first?.completedAt
            switch decide(startedAt: session.startedAt, lastSetAt: last, now: now, outsideGym: isOutside(of: gyms.first { $0.id == session.gymID }, from: here)) {
            case .keep: continue
            case let .finish(date):
                finish(session, at: date, context: context)
                closed.insert(id)
            case .discard:
                discard(session, context: context)
                closed.insert(id)
            }
        }
        return closed
    }

    static func finish(_ session: WorkoutSession, at date: Date = .now, context: ModelContext) {
        let id = session.id, gymID = session.gymID
        session.state = .finished
        session.endedAt = max(date, session.startedAt)
        context.saveReportingFailure()
        stopRest()
        AutoBackup.saveInBackground(from: context)
        let exerciseIDs = Set(((try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == id }))) ?? []).map(\.exerciseID))
        Task { @MainActor in await ProgressDiagnosis.refresh(exerciseIDs: exerciseIDs, gymID: gymID, context: context) }
    }

    static func discard(_ session: WorkoutSession, context: ModelContext) {
        let id = session.id
        for log in (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == id }))) ?? [] { context.delete(log) }
        for note in (try? context.fetch(FetchDescriptor<SessionNote>(predicate: #Predicate { $0.sessionID == id }))) ?? [] { context.delete(note) }
        context.delete(session)
        context.saveReportingFailure()
        stopRest()
    }

    /// A session that ends (finished, abandoned, closed by itself) takes its rest with it: no « Repos terminé » nor Live Activity after.
    static func stopRest() {
        RestActivity.end()
        NotificationService.cancelRestEnd()
    }

    /// False when the gym or the position is unknown: only the idle time then ends the session.
    private static func isOutside(of gym: Gym?, from here: CLLocation?) -> Bool {
        guard let gym, let lat = gym.latitude, let lon = gym.longitude, let here else { return false }
        return here.distance(from: CLLocation(latitude: lat, longitude: lon)) > gym.radius + margin
    }
}
