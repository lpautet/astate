import CoreData
import Foundation

extension CDMinMaxRecord {

    func configure(from record: MinMaxRecord) {
        id           = record.id
        lastUpdated  = record.lastUpdated
        minAltitude  = record.minAltitude
        maxAltitude  = record.maxAltitude
        minLatitude  = record.minLatitude
        maxLatitude  = record.maxLatitude
        minLongitude = record.minLongitude
        maxLongitude = record.maxLongitude
        minSpeed     = record.minSpeed
        maxSpeed     = record.maxSpeed
    }

    func toMinMaxRecord() -> MinMaxRecord {
        MinMaxRecord(
            id:           id ?? "minmax-singleton",
            lastUpdated:  lastUpdated ?? Date(),
            minAltitude:  minAltitude,
            maxAltitude:  maxAltitude,
            minLatitude:  minLatitude,
            maxLatitude:  maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude,
            minSpeed:     minSpeed,
            maxSpeed:     maxSpeed
        )
    }
}

extension MinMaxRecord {
    var coreDataDictionary: [String: Any] {
        ["id": id, "lastUpdated": lastUpdated,
         "minAltitude": minAltitude, "maxAltitude": maxAltitude,
         "minLatitude": minLatitude, "maxLatitude": maxLatitude,
         "minLongitude": minLongitude, "maxLongitude": maxLongitude,
         "minSpeed": minSpeed, "maxSpeed": maxSpeed]
    }
}
