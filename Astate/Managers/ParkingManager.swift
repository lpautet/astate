import Foundation
import CoreLocation
import SwiftUI

class ParkingManager: ObservableObject {
    private let latKey = "parking_latitude"
    private let lonKey = "parking_longitude"
    private let altKey = "parking_altitude"
    private let dateKey = "parking_date"

    @Published var parkingLocation: CLLocation?
    @Published var parkingDate: Date?

    init() { loadParking() }

    func saveParking(location: CLLocation) {
        UserDefaults.standard.set(location.coordinate.latitude, forKey: latKey)
        UserDefaults.standard.set(location.coordinate.longitude, forKey: lonKey)
        UserDefaults.standard.set(location.altitude, forKey: altKey)
        UserDefaults.standard.set(Date(), forKey: dateKey)
        parkingLocation = location
        parkingDate = Date()
    }

    func clearParking() {
        [latKey, lonKey, altKey, dateKey].forEach { UserDefaults.standard.removeObject(forKey: $0) }
        parkingLocation = nil
        parkingDate = nil
    }

    private func loadParking() {
        guard UserDefaults.standard.object(forKey: latKey) != nil else { return }
        let lat = UserDefaults.standard.double(forKey: latKey)
        let lon = UserDefaults.standard.double(forKey: lonKey)
        let alt = UserDefaults.standard.double(forKey: altKey)
        parkingLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: alt, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date()
        )
        parkingDate = UserDefaults.standard.object(forKey: dateKey) as? Date
    }

    func distanceAndBearing(from current: CLLocation) -> (Double, Double)? {
        guard let parking = parkingLocation else { return nil }
        let distance = current.distance(from: parking)
        let lat1 = current.coordinate.latitude * .pi / 180
        let lon1 = current.coordinate.longitude * .pi / 180
        let lat2 = parking.coordinate.latitude * .pi / 180
        let lon2 = parking.coordinate.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return (distance, bearing)
    }

    func cardinalDirection(from bearing: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return dirs[Int((bearing + 22.5) / 45.0) % 8]
    }
}
