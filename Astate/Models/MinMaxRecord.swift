import Foundation
import CloudKit

struct MinMaxRecord: Identifiable {
    let id: String
    let lastUpdated: Date
    let minAltitude: Double
    let maxAltitude: Double
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double
    let minSpeed: Double
    let maxSpeed: Double
    
    init(id: String = "minmax-singleton",
         lastUpdated: Date = Date(),
         minAltitude: Double = Double.infinity,
         maxAltitude: Double = -Double.infinity,
         minLatitude: Double = Double.infinity,
         maxLatitude: Double = -Double.infinity,
         minLongitude: Double = Double.infinity,
         maxLongitude: Double = -Double.infinity,
         minSpeed: Double = Double.infinity,
         maxSpeed: Double = -Double.infinity) {
        self.id = id
        self.lastUpdated = lastUpdated
        self.minAltitude = minAltitude
        self.maxAltitude = maxAltitude
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
    }
    
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "MinMaxRecord", recordID: recordID)
        record["lastUpdated"] = lastUpdated
        record["minAltitude"] = minAltitude
        record["maxAltitude"] = maxAltitude
        record["minLatitude"] = minLatitude
        record["maxLatitude"] = maxLatitude
        record["minLongitude"] = minLongitude
        record["maxLongitude"] = maxLongitude
        record["minSpeed"] = minSpeed
        record["maxSpeed"] = maxSpeed
        return record
    }
    
    // Create from CloudKit record
    static func fromCKRecord(_ record: CKRecord) -> MinMaxRecord? {
        guard let lastUpdated = record["lastUpdated"] as? Date,
              let minAltitude = record["minAltitude"] as? Double,
              let maxAltitude = record["maxAltitude"] as? Double,
              let minLatitude = record["minLatitude"] as? Double,
              let maxLatitude = record["maxLatitude"] as? Double,
              let minLongitude = record["minLongitude"] as? Double,
              let maxLongitude = record["maxLongitude"] as? Double else {
            return nil
        }
        
        // Handle speed fields with backward compatibility (might not exist in older records)
        let minSpeed = record["minSpeed"] as? Double ?? Double.infinity
        let maxSpeed = record["maxSpeed"] as? Double ?? -Double.infinity
        
        return MinMaxRecord(
            id: record.recordID.recordName,
            lastUpdated: lastUpdated,
            minAltitude: minAltitude,
            maxAltitude: maxAltitude,
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude,
            minSpeed: minSpeed,
            maxSpeed: maxSpeed
        )
    }
} 