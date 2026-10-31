import Foundation
import Observation
import SwiftData

/// Remembers that a save failed so the app can say it (a silent `try?` would lose the set without a word).
@MainActor
@Observable
final class SaveMonitor {
    static let shared = SaveMonitor()
    private(set) var failed = false

    func report() { failed = true }
    func dismiss() { failed = false }
}

extension ModelContext {
    /// Saves; on failure the banner of `RootView` tells the user.
    func saveReportingFailure() {
        do { try save() } catch {
            Diagnostics.record(.saveFailed, error.localizedDescription)
            Task { @MainActor in SaveMonitor.shared.report() }
        }
    }
}
