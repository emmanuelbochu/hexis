import CryptoKit
import Foundation
import SwiftData

/// The program lives in the bundled `Program.json`: edit the file, rebuild, and the app picks it up at launch.
/// Same sessions: the active program is updated in place; other sessions: a new program becomes the active one (older ones
/// stay inactive so past sessions keep their names). Only a change of exercises restarts the cycle and clears the app's tweaks;
/// a cue, a rest, a rep range or an exercise's name (`renamedFrom`) edited keeps them.
enum ProgramSync {
    private static let key = "programFileHash"
    private static let structureKey = "programStructureHash"
    private static let sessionsKey = "programSessionsHash"
    private static let namesKey = "programSessionNames"
    /// When the active program was loaded: its first week restarts the training cycle.
    static let startKey = "programStartedAt"

    static func sync(in context: ModelContext, url: URL? = ProgramCatalog.fileURL, defaults: UserDefaults = .standard) {
        guard let url, let data = try? Data(contentsOf: url) else { return }
        let hash = digest(data)
        guard defaults.string(forKey: key) != hash else { return }
        guard let spec = try? ProgramImporter.parse(data), (try? ProgramImporter.insert(spec, into: context)) != nil else {
            Diagnostics.record(.programSyncFailed, "Program.json could not be parsed or inserted")
            return
        }
        defaults.set(hash, forKey: key)
        // Exercises of each session: only a session already there that changes (or goes away) restarts the cycle.
        let exercises = Dictionary(spec.workouts.map { w in (w.name, w.blocks.flatMap { $0.exercises ?? [] }) }, uniquingKeysWith: { first, _ in first })
        func namesDigest(_ names: [String]) -> String { digest(Data(names.joined(separator: ",").utf8)) }
        let structure = exercises.mapValues { namesDigest($0.map(\.name)) }
        let previous = defaults.dictionary(forKey: sessionsKey) as? [String: String]
        let previousNames = defaults.dictionary(forKey: namesKey) as? [String: [String]]
        let changed: Bool
        if let previousNames {
            // A renamed exercise (`renamedFrom` is a name it had) is the same exercise: only another one restarts the cycle.
            changed = previousNames.contains { session, old in
                let oldSet = Set(old)
                return Set((exercises[session] ?? []).map { oldSet.contains($0.name) || !oldSet.contains($0.renamedFrom) ? $0.name : $0.renamedFrom }) != oldSet
            }
        } else if let previous {
            // Stored before the names were: a rename is told by the names its exercises had.
            let former = exercises.mapValues { namesDigest($0.map { $0.renamedFrom.isEmpty ? $0.name : $0.renamedFrom }) }
            changed = previous.contains { structure[$0.key] != $0.value && former[$0.key] != $0.value }
        } else {
            // Before the per-session key: the old whole-program hash, a fresh install has neither.
            changed = defaults.string(forKey: structureKey) != nil && defaults.string(forKey: structureKey) != legacyDigest(spec)
        }
        if changed || defaults.object(forKey: startKey) == nil {
            defaults.set(Date.now, forKey: startKey)
            try? context.delete(model: ExerciseTweak.self)
            context.saveReportingFailure()
        }
        defaults.set(structure, forKey: sessionsKey)
        defaults.set(exercises.mapValues { $0.map(\.name) }, forKey: namesKey)
        defaults.set(legacyDigest(spec), forKey: structureKey)
    }

    private static func legacyDigest(_ spec: ProgramSpec) -> String {
        digest(Data(spec.workouts.map { w in
            w.name + ":" + w.blocks.flatMap { $0.exercises ?? [] }.map(\.name).joined(separator: ",")
        }.joined(separator: "|").utf8))
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
