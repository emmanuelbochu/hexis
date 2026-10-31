import SwiftData

/// V13 adds `ShoppingNote` (off-plan items for this week's shopping only).
enum SchemaV13: VersionedSchema {
    static var versionIdentifier = Schema.Version(13, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV12.models + [ShoppingNote.self]
    }
}
