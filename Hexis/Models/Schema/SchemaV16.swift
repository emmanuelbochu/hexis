import SwiftData

/// V16 adds `FlatStock` (what is at the flat of the foods kept there).
enum SchemaV16: VersionedSchema {
    static var versionIdentifier = Schema.Version(16, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV15.models + [FlatStock.self]
    }
}
