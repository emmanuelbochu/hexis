import CoreLocation
import MapKit

/// Finds a gym's coordinates from its name ("Basic-Fit CityA") with a map search, so no GPS visit is needed.
enum GymGeocoder {
    /// The first result named like the gym (Basic-Fit...) and located in the city of the name; nil otherwise.
    static func coordinate(forGymNamed name: String) async -> CLLocationCoordinate2D? {
        guard let city = name.split(separator: " ").last.map(String.init) else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(name) France"
        request.resultTypes = .pointOfInterest
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        let brand = name.split(separator: " ").first.map(String.init) ?? name
        return response.mapItems.first {
            ($0.name ?? "").localizedCaseInsensitiveContains(brand)
                && ($0.placemark.locality ?? "").localizedCaseInsensitiveContains(city)
        }?.placemark.coordinate
    }
}
