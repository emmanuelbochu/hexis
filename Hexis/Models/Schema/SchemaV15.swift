import SwiftData

/// V15 adds `OffPlanProduct` (off-plan receipt lines the user explained).
enum SchemaV15: VersionedSchema {
    static var versionIdentifier = Schema.Version(15, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV14.models + [OffPlanProduct.self]
    }
}
