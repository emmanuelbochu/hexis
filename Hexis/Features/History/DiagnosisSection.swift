import SwiftData
import SwiftUI

/// The AI's latest reading of this exercise (written in the background after a session when it stalled or dropped); hidden otherwise.
struct DiagnosisSection: View {
    @Query(filter: #Predicate<AIInsight> { $0.kind == "progress" }) private var cached: [AIInsight]
    let exerciseID: UUID

    var body: some View {
        if let text = ProgressDiagnosis.latest(for: exerciseID, in: cached) {
            Section("Lecture") {
                Text(text).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
            }
            .listRowBackground(Theme.Colors.surface)
        }
    }
}
