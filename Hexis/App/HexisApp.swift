import SwiftData
import SwiftUI

@main
struct HexisApp: App {
    private let container: ModelContainer?
    private let failure: String

    init() {
        _ = Diagnostics.launchedAt
        MetricsReporter.shared.start()
        Theme.applyAppearance()
        do {
            container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV16.self),
                migrationPlan: HexisMigrationPlan.self
            )
            failure = ""
        } catch {
            container = nil
            failure = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .appAppearance()
                    .modelContainer(container)
            } else {
                RecoveryView(error: failure)
                    .appAppearance()
            }
        }
    }
}
