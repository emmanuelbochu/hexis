import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroup: String
    var isUnilateral: Bool

    init(id: UUID = UUID(), name: String, muscleGroup: String = "", isUnilateral: Bool = false) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.isUnilateral = isUnilateral
    }
}
