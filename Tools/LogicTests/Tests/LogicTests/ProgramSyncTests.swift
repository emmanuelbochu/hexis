import Foundation
import SwiftData
import Testing
@testable import HexisLogic

/// A new `Program.json` restarts the cycle only when the sessions already lived change, not when sessions are added.
@Suite(.serialized) struct ProgramSyncTests {
    static let bundled = LifeSimulator.programFile

    /// The bundled program, its workouts filtered and edited, written to a temporary file.
    func file(_ name: String, edit: (inout [[String: Any]]) -> Void) throws -> URL {
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: Self.bundled)) as? [String: Any])
        var workouts = try #require(json["workouts"] as? [[String: Any]])
        edit(&workouts)
        json["workouts"] = workouts
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("program-\(name)-\(UUID()).json")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        return url
    }

    @Test @MainActor func addingSessionsKeepsTheCycleAndTheTweaks() throws {
        let defaults = try #require(UserDefaults(suiteName: "ProgramSyncTests-\(UUID())"))
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let usual = try file("usual") { $0.removeAll { ($0["replaces"] as? [String]) != nil } }
        ProgramSync.sync(in: context, url: usual, defaults: defaults)
        let started = Date(timeIntervalSince1970: 1_790_000_000)
        defaults.set(started, forKey: ProgramSync.startKey)
        context.insert(ExerciseTweak(exerciseID: UUID(), gymID: nil, setsDelta: 1))
        try context.save()

        ProgramSync.sync(in: context, url: Self.bundled, defaults: defaults)
        #expect(defaults.object(forKey: ProgramSync.startKey) as? Date == started)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseTweak>()) == 1)

        // An exercise taken out of a lived session does restart it.
        let changed = try file("changed") { workouts in
            guard var blocks = workouts[0]["blocks"] as? [[String: Any]] else { return }
            blocks.removeLast()
            workouts[0]["blocks"] = blocks
        }
        ProgramSync.sync(in: context, url: changed, defaults: defaults)
        #expect(defaults.object(forKey: ProgramSync.startKey) as? Date != started)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseTweak>()) == 0)
    }

    /// A shorter name (`renamedFrom`) keeps the exercise, its history and the cycle: only a change of exercises restarts it.
    @Test @MainActor func renamingAnExerciseKeepsTheCycleAndTheHistory() throws {
        let defaults = try #require(UserDefaults(suiteName: "ProgramSyncTests-\(UUID())"))
        let container = try ModelContainer(for: Schema(versionedSchema: SchemaV16.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        ProgramSync.sync(in: context, url: Self.bundled, defaults: defaults)
        let started = Date(timeIntervalSince1970: 1_790_000_000)
        defaults.set(started, forKey: ProgramSync.startKey)
        let before = try context.fetch(FetchDescriptor<Exercise>())
        let item = try #require(try context.fetch(FetchDescriptor<Program>()).first?.templates.first?.blocks.first?.exercises.first)
        let target = try #require(before.first { $0.id == item.exerciseID })
        let renamed = try file("renamed") { workouts in
            for w in workouts.indices {
                guard var blocks = workouts[w]["blocks"] as? [[String: Any]] else { continue }
                for b in blocks.indices {
                    guard var exercises = blocks[b]["exercises"] as? [[String: Any]] else { continue }
                    for e in exercises.indices where exercises[e]["name"] as? String == target.name {
                        exercises[e]["renamedFrom"] = target.name
                        exercises[e]["name"] = "Nom court"
                    }
                    blocks[b]["exercises"] = exercises
                }
                workouts[w]["blocks"] = blocks
            }
        }
        ProgramSync.sync(in: context, url: renamed, defaults: defaults)
        #expect(defaults.object(forKey: ProgramSync.startKey) as? Date == started, "a rename does not restart the cycle")
        let after = try context.fetch(FetchDescriptor<Exercise>())
        #expect(after.first { $0.id == target.id }?.name == "Nom court", "same exercise, same history")
        #expect(after.count == before.count)
    }
}
