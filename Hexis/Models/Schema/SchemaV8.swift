import SwiftData

/// V8 adds `PurchaseLog` (scanned receipt lines: quantities and prices over time).
enum SchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV7.models + [PurchaseLog.self]
    }
}
