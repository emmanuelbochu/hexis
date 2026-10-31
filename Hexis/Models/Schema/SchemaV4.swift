import SwiftData

/// V4 adds `ExerciseFeeling` (one-tap feeling per exercise and session). Existing models are unchanged.
enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV3.models + [ExerciseFeeling.self]
    }
}
