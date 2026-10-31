import Foundation
import SwiftData

@Model
final class Gym {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double?
    var longitude: Double?
    var radius: Double

    init(id: UUID = UUID(), name: String, latitude: Double? = nil, longitude: Double? = nil, radius: Double = 150) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}
