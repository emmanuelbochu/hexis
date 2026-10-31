import SwiftData

/// V12 adds `ExerciseTweak` (sets or rep range changed by the app after a plateau).
enum SchemaV12: VersionedSchema {
    static var versionIdentifier = Schema.Version(12, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV11.models + [ExerciseTweak.self]
    }
}
