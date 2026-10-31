import CoreLocation
import Foundation

/// Checks that gyms can really be told apart by GPS.
enum GymSetup {
    struct Item {
        var id: UUID
        var name: String
        var latitude: Double?
        var longitude: Double?
        var radius: Double
    }

    enum Issue: Equatable {
        case notSet
        /// Another gym's detection zone overlaps this one.
        case tooClose(String)

        var message: String {
            switch self {
            case .notSet: "Position non définie : la salle ne sera pas détectée."
            case .tooClose(let other): "Trop proche de \(other) : détection ambiguë, redéfinis la position sur place."
            }
        }
    }

    /// Saved positions worse than this are refused (indoors GPS can drift a lot).
    static let maxAccuracy: Double = 100

    static func issue(for gym: Item, among all: [Item]) -> Issue? {
        guard let lat = gym.latitude, let lon = gym.longitude else { return .notSet }
        let here = CLLocation(latitude: lat, longitude: lon)
        for other in all where other.id != gym.id {
            guard let oLat = other.latitude, let oLon = other.longitude else { continue }
            if here.distance(from: CLLocation(latitude: oLat, longitude: oLon)) <= gym.radius + other.radius {
                return .tooClose(other.name)
            }
        }
        return nil
    }
}

extension Gym {
    var setupItem: GymSetup.Item {
        .init(id: id, name: name, latitude: latitude, longitude: longitude, radius: radius)
    }
}
