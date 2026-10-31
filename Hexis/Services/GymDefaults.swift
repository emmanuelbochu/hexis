import CoreLocation
import Foundation
import SwiftData

/// The user's two gyms: created at first launch, and the old placeholder names renamed.
enum GymDefaults {
    static let names = Edition.isElle ? ["Wake Up Form", "Basic-Fit CityB"] : ["Basic-Fit CityA", "Basic-Fit CityB"]
    /// Addresses looked up on the web and their coordinates (OpenStreetMap), so no GPS visit is needed.
    struct Place {
        var address: String
        var latitude: Double
        var longitude: Double
    }

    static let places: [String: Place] = [
        "Basic-Fit CityA": Place(address: "1 Example Street, City A", latitude: 43.0000001, longitude: 4.0000001),
        // Hexis Elle's usual gym (L'Isle-sur-la-Sorgue, 225 av. André Ampère): the street's position, to refine on site if needed.
        "Wake Up Form": Place(address: "225 avenue André Ampère, ZA La Grande Marine, L'Isle-sur-la-Sorgue", latitude: 43.9196713, longitude: 5.0335528),
        "Basic-Fit CityB": Place(address: "2 Example Road, City B", latitude: 44.0000002, longitude: 5.0000002),
    ]

    /// A gym with its known position when the name is one of the user's gyms.
    static func makeGym(named name: String) -> Gym {
        let place = places[name]
        return Gym(name: name, latitude: place?.latitude, longitude: place?.longitude)
    }

    /// The gym when the GPS does not decide: hers is always the usual one; his follows `GymRule`.
    static func fallbackName(on date: Date) -> String {
        if Edition.isElle { return "Wake Up Form" }
        return GymRule.usesCityB(on: date) ? "CityB" : "CityA"
    }

    private static let renames = ["Basic-Fit A": "Basic-Fit CityA", "Basic-Fit B": "Basic-Fit CityB"]

    static func seed(in context: ModelContext) {
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        for gym in gyms { if let new = renames[gym.name] { gym.name = new } }
        if gyms.isEmpty { names.forEach { context.insert(makeGym(named: $0)) } }
        context.saveReportingFailure()
    }

    /// Fills the position of gyms that have none: known address first, else a map search on the name.
    static func locateMissing(in context: ModelContext) async {
        let gyms = ((try? context.fetch(FetchDescriptor<Gym>())) ?? []).filter { $0.latitude == nil }
        for gym in gyms {
            if let place = places[gym.name] {
                gym.latitude = place.latitude
                gym.longitude = place.longitude
                continue
            }
            guard let coordinate = await GymGeocoder.coordinate(forGymNamed: gym.name) else { continue }
            gym.latitude = coordinate.latitude
            gym.longitude = coordinate.longitude
        }
        context.saveReportingFailure()
    }
}
