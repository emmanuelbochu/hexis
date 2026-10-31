import SwiftData

/// V14 adds `ProductMemory` (products learned from the receipts, and the pack sizes typed by hand).
enum SchemaV14: VersionedSchema {
    static var versionIdentifier = Schema.Version(14, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV13.models + [ProductMemory.self]
    }
}
