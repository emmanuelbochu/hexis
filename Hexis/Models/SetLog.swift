import Foundation
import SwiftData

enum SetKind: String, Codable {
    case warmup, work
}

enum SetSide: String, Codable {
    case left, right
}

@Model
final class SetLog {
    var sessionID: UUID
    var exerciseID: UUID
    var gymID: UUID?
    var index: Int
    var kindRaw: String
    var weight: Double
    var reps: Int
    var rir: Int?
    var completedAt: Date
    var sideRaw: String?

    var kind: SetKind {
        get { SetKind(rawValue: kindRaw) ?? .work }
        set { kindRaw = newValue.rawValue }
    }

    var side: SetSide? {
        get { sideRaw.flatMap(SetSide.init(rawValue:)) }
        set { sideRaw = newValue?.rawValue }
    }

    init(
        sessionID: UUID, exerciseID: UUID, gymID: UUID?, index: Int, kind: SetKind = .work,
        weight: Double, reps: Int, rir: Int? = nil, completedAt: Date = .now, side: SetSide? = nil
    ) {
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.gymID = gymID
        self.index = index
        self.kindRaw = kind.rawValue
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.completedAt = completedAt
        self.sideRaw = side?.rawValue
    }
}
