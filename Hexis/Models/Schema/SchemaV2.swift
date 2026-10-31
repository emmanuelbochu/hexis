import SwiftData

/// V2 adds `SessionNote` (session/exercise notes and pain flag). Existing models are unchanged.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV1.models + [SessionNote.self]
    }
}
