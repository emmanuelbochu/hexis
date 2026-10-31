import SwiftData

/// V5 adds `FoodEntry` (nutrition log). Existing models are unchanged.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV4.models + [FoodEntry.self]
    }
}
