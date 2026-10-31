import Foundation
import SwiftData

/// Pain and tiredness flags, the end-of-session review, load profiles and totals.
extension WorkoutViewModel {
    /// « Gêne » on this exercise in this session (tap again to clear).
    func hasPain(_ exerciseID: UUID) -> Bool { sessionFeelings[exerciseID] == .pain }

    func togglePain(_ exerciseID: UUID) { setFeeling(.pain, on: !hasPain(exerciseID), exerciseID: exerciseID) }

    /// « Fatigué » is about the whole day: kept on the session (stored with the session id as exercise id).
    var isTired: Bool { sessionFeelings[session.id] == .tired }

    /// Marking the day tired holds the loads of the exercises not started yet (no increase today).
    func toggleTired() {
        setFeeling(.tired, on: !isTired, exerciseID: session.id)
        let started = Set(done.map { steps[$0].exerciseID })
        applyDefaults(to: steps.indices.filter { !done.contains($0) && !started.contains(steps[$0].exerciseID) })
    }

    func setFeeling(_ feeling: Feeling, on: Bool, exerciseID: UUID) {
        let sessionID = session.id
        for entry in (try? context.fetch(FetchDescriptor<ExerciseFeeling>(predicate: #Predicate { $0.sessionID == sessionID && $0.exerciseID == exerciseID }))) ?? [] {
            context.delete(entry)
        }
        if on { context.insert(ExerciseFeeling(sessionID: sessionID, exerciseID: exerciseID, feeling: feeling)) }
        context.saveReportingFailure()
        sessionFeelings[exerciseID] = on ? feeling : nil
    }

    /// Feeling chosen for the exercise in its last session (a pain flag from before counts as `.pain`).
    func lastFeeling(_ exerciseID: UUID) -> Feeling? {
        if let cached = feelingCache[exerciseID] { return cached }
        let current = session.id
        var descriptor = FetchDescriptor<ExerciseFeeling>(
            predicate: #Predicate { $0.exerciseID == exerciseID && $0.sessionID != current },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        var feeling = (try? context.fetch(descriptor).first)?.feeling
        if feeling == nil {
            var legacy = FetchDescriptor<SessionNote>(
                predicate: #Predicate { $0.exerciseID == exerciseID && $0.sessionID != current && $0.hasPain }
            )
            legacy.fetchLimit = 1
            if (try? context.fetch(legacy).first) != nil { feeling = .pain }
        }
        feelingCache[exerciseID] = .some(feeling)
        return feeling
    }

    /// Records and volume trend of this session, for the end screen (only the exercises of the session are read).
    var review: SessionReview {
        let current = session.id
        let started = session.startedAt
        let template = session.templateID
        let mine = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == current }))) ?? []
        let exerciseIDs = Array(Set(mine.map(\.exerciseID)))
        let earlier = (try? context.fetch(FetchDescriptor<SetLog>(
            predicate: #Predicate { exerciseIDs.contains($0.exerciseID) && $0.sessionID != current && $0.completedAt < started }
        ))) ?? []
        let names = Dictionary(
            ((try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { exerciseIDs.contains($0.id) }))) ?? []).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        var previous = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw == "finished" && $0.templateID == template && $0.startedAt < started && $0.id != current },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        previous.fetchLimit = 1
        let previousVolume = (try? context.fetch(previous))?.first.map { last in
            let lastID = last.id
            let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == lastID && $0.kindRaw == "work" }))) ?? []
            return sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
        }
        return SessionReview(sessionSets: mine, earlierSets: earlier, names: names, previousVolume: previousVolume)
    }

    /// Rows to display for a group: a single warmup (the next one to do), then all the work sets.
    func visibleRows(_ group: ExerciseGroup) -> [Int] {
        let warmups = group.indices.filter { steps[$0].warmupPercent != nil && !skipped.contains($0) }
        let nextWarmup = warmups.first { !done.contains($0) }
        return (nextWarmup.map { [$0] } ?? []) + group.indices.filter { steps[$0].warmupPercent == nil }
    }

    var volume: Double {
        done.reduce(0) { total, i in
            guard steps[i].warmupPercent == nil, let v = values[i] else { return total }
            return total + loadProfile(steps[i].exerciseID, name: steps[i].name).effective(v.weight) * Double(v.reps)
        }
    }

    func loadProfile(_ exerciseID: UUID, name: String) -> LoadProfile {
        loads[exerciseID] ?? .guess(name: name)
    }

    func setLoad(_ profile: LoadProfile, for exerciseID: UUID) {
        loads[exerciseID] = profile
        let existing = (try? context.fetch(FetchDescriptor<ExerciseLoad>(predicate: #Predicate { $0.exerciseID == exerciseID })))?.first
        if let existing {
            existing.kindRaw = profile.kind.rawValue
            existing.baseWeight = profile.base
        } else {
            context.insert(ExerciseLoad(exerciseID: exerciseID, kind: profile.kind, baseWeight: profile.base))
        }
        context.saveReportingFailure()
    }

    var workSetsDone: Int { done.filter { steps[$0].warmupPercent == nil && steps[$0].side != .left }.count }

    /// Stats of the session so far, for the end-of-workout screen.
    var summary: SessionSummary {
        let sessionID = session.id
        let sets = (try? context.fetch(FetchDescriptor<SetLog>(predicate: #Predicate { $0.sessionID == sessionID }))) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let resolver = LoadResolver(loads: ((try? context.fetch(FetchDescriptor<ExerciseLoad>())) ?? []), exercises: exercises)
        return SessionSummary(sets: sets, startedAt: session.startedAt, endedAt: session.endedAt, loads: resolver)
    }
}
