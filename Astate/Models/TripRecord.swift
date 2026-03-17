import Foundation
import CloudKit

struct TripRecord: Identifiable {
    let id: String
    var name: String
    var startDate: Date
    var endDate: Date
    var totalDistance: Double    // meters
    var elevationGain: Double    // meters
    var elevationLoss: Double    // meters
    var duration: TimeInterval   // seconds
    var avgSpeed: Double         // m/s
    var pointCount: Int

    init(id: String = UUID().uuidString,
         name: String,
         startDate: Date,
         endDate: Date,
         totalDistance: Double,
         elevationGain: Double,
         elevationLoss: Double,
         duration: TimeInterval,
         avgSpeed: Double,
         pointCount: Int) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.totalDistance = totalDistance
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.duration = duration
        self.avgSpeed = avgSpeed
        self.pointCount = pointCount
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "TripRecord")
        record["name"] = name as CKRecordValue
        record["startDate"] = startDate as CKRecordValue
        record["endDate"] = endDate as CKRecordValue
        record["totalDistance"] = totalDistance as CKRecordValue
        record["elevationGain"] = elevationGain as CKRecordValue
        record["elevationLoss"] = elevationLoss as CKRecordValue
        record["duration"] = duration as CKRecordValue
        record["avgSpeed"] = avgSpeed as CKRecordValue
        record["pointCount"] = pointCount as CKRecordValue
        return record
    }

    static func fromCKRecord(_ record: CKRecord) -> TripRecord? {
        guard let name = record["name"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let totalDistance = record["totalDistance"] as? Double,
              let elevationGain = record["elevationGain"] as? Double,
              let elevationLoss = record["elevationLoss"] as? Double,
              let duration = record["duration"] as? Double,
              let avgSpeed = record["avgSpeed"] as? Double,
              let pointCount = record["pointCount"] as? Int
        else { return nil }

        return TripRecord(
            id: record.recordID.recordName,
            name: name,
            startDate: startDate,
            endDate: endDate,
            totalDistance: totalDistance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            duration: duration,
            avgSpeed: avgSpeed,
            pointCount: pointCount
        )
    }
}
