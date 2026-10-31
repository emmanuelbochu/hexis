import CoreLocation
import Foundation

/// Pure matching of a position to the closest gym whose radius contains it.
enum GymLocator {
    struct Candidate {
        var id: UUID
        var latitude: Double
        var longitude: Double
        var radius: Double
    }

    static func nearest(to location: CLLocation, among gyms: [Candidate]) -> UUID? {
        gyms
            .map { ($0, location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))) }
            .filter { $0.1 <= $0.0.radius }
            .min { $0.1 < $1.1 }?
            .0.id
    }
}
