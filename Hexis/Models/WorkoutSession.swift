import Foundation
import SwiftData

enum SessionState: String, Codable {
    case inProgress, finished
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var gymID: UUID?
    var templateID: UUID?
    var startedAt: Date
    var endedAt: Date?
    var stateRaw: String

    var state: SessionState {
        get { SessionState(rawValue: stateRaw) ?? .inProgress }
        set { stateRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date = .now, gymID: UUID? = nil, templateID: UUID? = nil) {
        self.id = id
        self.date = date
        self.gymID = gymID
        self.templateID = templateID
        self.startedAt = date
        self.stateRaw = SessionState.inProgress.rawValue
    }
}
