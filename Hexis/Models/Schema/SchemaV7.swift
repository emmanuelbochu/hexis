import SwiftData

/// V7 adds `ExerciseLoad` (meaning of the typed weight) and `DeloadWeek` (planned deload).
enum SchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(7, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV6.models + [ExerciseLoad.self, DeloadWeek.self]
    }
}
