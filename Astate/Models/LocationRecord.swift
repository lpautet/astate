import Foundation
import CloudKit

struct LocationRecord: Identifiable {
    let id: String
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    
    init(id: String = UUID().uuidString,
         timestamp: Date = Date(),
         latitude: Double,
         longitude: Double,
         altitude: Double) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
    
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "LocationRecord")
        record["timestamp"] = timestamp
        record["latitude"] = latitude
        record["longitude"] = longitude
        record["altitude"] = altitude
        return record
    }
    
    // Create from CloudKit record
    static func fromCKRecord(_ record: CKRecord) -> LocationRecord? {
        guard let timestamp = record["timestamp"] as? Date,
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double,
              let altitude = record["altitude"] as? Double else {
            return nil
        }
        
        return LocationRecord(
            id: record.recordID.recordName,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude
        )
    }
} 