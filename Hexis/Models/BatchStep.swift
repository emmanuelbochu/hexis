import Foundation
import SwiftData

/// One step of the Sunday batch cooking. Done when completed since the start of the current cycle.
@Model
final class BatchStep {
    @Attribute(.unique) var id: UUID
    var order: Int
    var title: String
    var detail: String
    /// Optional countdown for the step, in seconds (0 = none).
    var timerSeconds: Int
    var completedAt: Date?

    init(id: UUID = UUID(), order: Int, title: String, detail: String, timerSeconds: Int = 0, completedAt: Date? = nil) {
        self.id = id
        self.order = order
        self.title = title
        self.detail = detail
        self.timerSeconds = timerSeconds
        self.completedAt = completedAt
    }

    func isDone(now: Date = .now) -> Bool {
        completedAt.map { $0 >= PlanCycle.batchWindowStart(for: now) } ?? false
    }
}
