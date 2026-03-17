import CoreData
import Foundation

extension CDTripRecord {

    func configure(from trip: TripRecord) {
        id            = trip.id
        name          = trip.name
        startDate     = trip.startDate
        endDate       = trip.endDate
        totalDistance = trip.totalDistance
        elevationGain = trip.elevationGain
        elevationLoss = trip.elevationLoss
        duration      = trip.duration
        avgSpeed      = trip.avgSpeed
        pointCount    = Int32(trip.pointCount)
    }

    func toTripRecord() -> TripRecord {
        TripRecord(
            id:            id ?? UUID().uuidString,
            name:          name ?? "",
            startDate:     startDate ?? Date(),
            endDate:       endDate ?? Date(),
            totalDistance: totalDistance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            duration:      duration,
            avgSpeed:      avgSpeed,
            pointCount:    Int(pointCount)
        )
    }
}

extension TripRecord {
    var coreDataDictionary: [String: Any] {
        ["id": id, "name": name, "startDate": startDate, "endDate": endDate,
         "totalDistance": totalDistance, "elevationGain": elevationGain,
         "elevationLoss": elevationLoss, "duration": duration,
         "avgSpeed": avgSpeed, "pointCount": Int32(pointCount)]
    }
}
