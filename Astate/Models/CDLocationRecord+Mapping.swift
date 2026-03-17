import CoreData
import Foundation

extension CDLocationRecord {

    func configure(from record: LocationRecord) {
        id        = record.id
        timestamp = record.timestamp
        latitude  = record.latitude
        longitude = record.longitude
        altitude  = record.altitude
    }

    func toLocationRecord() -> LocationRecord {
        LocationRecord(
            id:        id ?? UUID().uuidString,
            timestamp: timestamp ?? Date(),
            latitude:  latitude,
            longitude: longitude,
            altitude:  altitude
        )
    }
}

extension LocationRecord {
    var coreDataDictionary: [String: Any] {
        ["id": id, "timestamp": timestamp, "latitude": latitude,
         "longitude": longitude, "altitude": altitude]
    }
}
