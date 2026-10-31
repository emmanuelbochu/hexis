import SwiftData

/// V11 adds `ExtraPurchase` (receipt lines outside the plan).
enum SchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(11, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV10.models + [ExtraPurchase.self]
    }
}
