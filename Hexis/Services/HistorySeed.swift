import Foundation
import SwiftData

/// Her history from before the app (Hevy, converted by `Tools/hevy_import.py` into the bundled `HevyHistory.json`), loaded once at launch
/// into the usual gym: the next goals, the warmups and the machines' weights start from what she really lifted instead of the
/// program's guesses. Only Hexis Elle bundles the file. Nothing is asked or shown; the sessions have fixed ids, so loading twice,
/// or after a restored backup that already holds them, adds nothing.
enum HistorySeed {
    static let versionKey = "historySeedVersion"
    static let fileURL = Bundle.main.url(forResource: "HevyHistory", withExtension: "json")

    struct File: Decodable {
        var version: Int
        var exercises: [Lift]
        var sessions: [Entry]
    }

    struct Lift: Decodable {
        var name: String
        var muscle: String?
        /// How the typed number reads for a lift outside her program (`perHand`, `stack`, `total`); nil = the app's own guess.
        var load: String?
    }

    struct Entry: Decodable {
        var id: UUID
        var start: Date
        var end: Date
        var template: String?
        var sets: [Item]
    }

    struct Item: Decodable {
        var exercise: String
        var weight: Double
        var reps: Int
    }

    /// Imported sessions carry a version-5 UUID (made from the Hevy date); the app's own are random (version 4). Lets the learning
    /// that needs real sessions (durations, plateaus, rests) leave them out, without a flag in the models.
    static func isImported(_ id: UUID) -> Bool {
        let text = id.uuidString
        return text[text.index(text.startIndex, offsetBy: 14)] == "5"
    }

    @discardableResult
    static func seed(in context: ModelContext, url: URL? = fileURL, defaults: UserDefaults = .standard) -> Bool {
        guard let url, let data = try? Data(contentsOf: url) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(File.self, from: data), defaults.integer(forKey: versionKey) < file.version else { return false }

        GymDefaults.seed(in: context)
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        let gym = gyms.first { $0.name == GymDefaults.fallbackName(on: .now) } ?? gyms.first
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let templateIDs = Dictionary((templates.filter { $0.program?.isActive == true }).map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })

        var exercises = Dictionary(((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let loaded = Set(((try? context.fetch(FetchDescriptor<ExerciseLoad>())) ?? []).map(\.exerciseID))
        for lift in file.exercises {
            let key = lift.name.lowercased()
            let exercise = exercises[key] ?? Exercise(name: lift.name, muscleGroup: lift.muscle ?? "")
            if exercises[key] == nil {
                context.insert(exercise)
                exercises[key] = exercise
            }
            if let raw = lift.load, let kind = LoadKind(rawValue: raw), !loaded.contains(exercise.id) {
                context.insert(ExerciseLoad(exerciseID: exercise.id, kind: kind, baseWeight: 0))
            }
        }

        // A newer file replaces what an older one loaded (same ids): never twice, never a duplicate.
        let ids = file.sessions.map(\.id)
        try? context.delete(model: SetLog.self, where: #Predicate { ids.contains($0.sessionID) })
        try? context.delete(model: WorkoutSession.self, where: #Predicate { ids.contains($0.id) })
        for entry in file.sessions {
            let session = WorkoutSession(id: entry.id, date: entry.start, gymID: gym?.id, templateID: entry.template.flatMap { templateIDs[$0] })
            session.endedAt = entry.end
            session.state = .finished
            context.insert(session)
            for (index, item) in entry.sets.enumerated() {
                guard let exercise = exercises[item.exercise.lowercased()] else { continue }
                context.insert(SetLog(
                    sessionID: entry.id, exerciseID: exercise.id, gymID: gym?.id, index: index,
                    weight: item.weight, reps: item.reps, completedAt: entry.start
                ))
            }
        }
        context.saveReportingFailure()
        defaults.set(file.version, forKey: versionKey)
        return true
    }
}
