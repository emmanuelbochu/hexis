import SwiftData

/// V3 adds `CarryNote` (note kept for the next session of an exercise). Existing models are unchanged.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV2.models + [CarryNote.self]
    }
}
