import SwiftData

/// V10 adds `ReceiptAlias` (receipt lines the user corrected).
enum SchemaV10: VersionedSchema {
    static var versionIdentifier = Schema.Version(10, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV9.models + [ReceiptAlias.self]
    }
}
