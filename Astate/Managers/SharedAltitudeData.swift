import Foundation

struct AltitudeDataPoint: Codable {
    let timestamp: Date
    let altitude: Double
}

struct SharedAltitudeData: Codable {
    var currentAltitude: Double
    var todayElevationGain: Double
    var recentPoints: [AltitudeDataPoint]
    var lastUpdated: Date

    static let suiteName = "group.com.pautet.app.Astate"
    static let key = "altitude_data"

    static func load() -> SharedAltitudeData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedAltitudeData.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: SharedAltitudeData.suiteName),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: SharedAltitudeData.key)
    }
}
