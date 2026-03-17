import CoreData
import Foundation

final class CoreDataManager: @unchecked Sendable {

    static let shared = CoreDataManager()

    // MARK: - Stack

    let container: NSPersistentContainer

    var mainContext: NSManagedObjectContext { container.viewContext }

    private(set) lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()

    private init() {
        container = NSPersistentContainer(name: "AstatePersistence")
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.loadPersistentStores { _, error in
            if let error {
                // Non-fatal: log and continue; app falls back to CloudKit
                print("[CoreData] Failed to load store: \(error)")
            }
        }
    }

    // MARK: - Sync Metadata

    enum SyncKey: String {
        case locationRecords = "lastSync_location"
        case tripRecords     = "lastSync_trip"
        case minMaxRecord    = "lastSync_minmax"
    }

    func lastSyncDate(for key: SyncKey) -> Date? {
        UserDefaults.standard.object(forKey: key.rawValue) as? Date
    }

    func setLastSyncDate(_ date: Date, for key: SyncKey) {
        UserDefaults.standard.set(date, forKey: key.rawValue)
    }

    // MARK: - LocationRecord

    func saveLocationRecord(_ record: LocationRecord) async {
        await backgroundContext.perform {
            let existing = self.findLocationRecord(id: record.id, in: self.backgroundContext)
            let cd = existing ?? CDLocationRecord(context: self.backgroundContext)
            cd.configure(from: record)
            self.saveBackground()
        }
    }

    func batchInsertLocationRecords(_ records: [LocationRecord]) async {
        guard !records.isEmpty else { return }
        await backgroundContext.perform {
            let insertRequest = NSBatchInsertRequest(
                entity: CDLocationRecord.entity(),
                objects: records.map { $0.coreDataDictionary }
            )
            insertRequest.resultType = .statusOnly
            _ = try? self.backgroundContext.execute(insertRequest)
            NotificationCenter.default.post(
                name: .NSManagedObjectContextDidSave,
                object: self.backgroundContext
            )
        }
    }

    func fetchLocationRecords(from start: Date, to end: Date) -> [LocationRecord] {
        let request = CDLocationRecord.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                        start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        request.fetchBatchSize = 50
        return (try? mainContext.fetch(request))?.map { $0.toLocationRecord() } ?? []
    }

    func locationRecordCount() -> Int {
        let request = CDLocationRecord.fetchRequest()
        return (try? mainContext.count(for: request)) ?? 0
    }

    func pruneLocationRecordsOlderThan30Days() async {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        await backgroundContext.perform {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CDLocationRecord")
            request.predicate = NSPredicate(format: "timestamp < %@", cutoff as NSDate)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            do {
                let result = try self.backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
                if let ids = result?.result as? [NSManagedObjectID], !ids.isEmpty {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                        into: [self.container.viewContext]
                    )
                }
            } catch {
                print("[CoreData] Prune failed: \(error)")
            }
        }
    }

    // MARK: - TripRecord

    func saveTripRecord(_ trip: TripRecord) async {
        await backgroundContext.perform {
            let existing = self.findTripRecord(id: trip.id, in: self.backgroundContext)
            let cd = existing ?? CDTripRecord(context: self.backgroundContext)
            cd.configure(from: trip)
            self.saveBackground()
        }
    }

    func batchInsertTripRecords(_ trips: [TripRecord]) async {
        guard !trips.isEmpty else { return }
        await backgroundContext.perform {
            let insertRequest = NSBatchInsertRequest(
                entity: CDTripRecord.entity(),
                objects: trips.map { $0.coreDataDictionary }
            )
            insertRequest.resultType = .statusOnly
            _ = try? self.backgroundContext.execute(insertRequest)
            NotificationCenter.default.post(
                name: .NSManagedObjectContextDidSave,
                object: self.backgroundContext
            )
        }
    }

    func fetchTripRecords() -> [TripRecord] {
        let request = CDTripRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return (try? mainContext.fetch(request))?.map { $0.toTripRecord() } ?? []
    }

    func tripRecordCount() -> Int {
        let request = CDTripRecord.fetchRequest()
        return (try? mainContext.count(for: request)) ?? 0
    }

    // MARK: - MinMaxRecord

    func saveMinMaxRecord(_ record: MinMaxRecord) async {
        await backgroundContext.perform {
            let existing = self.findMinMaxRecord(in: self.backgroundContext)
            let cd = existing ?? CDMinMaxRecord(context: self.backgroundContext)
            cd.configure(from: record)
            self.saveBackground()
        }
    }

    func fetchMinMaxRecord() -> MinMaxRecord? {
        let request = CDMinMaxRecord.fetchRequest()
        request.fetchLimit = 1
        return (try? mainContext.fetch(request))?.first?.toMinMaxRecord()
    }

    // MARK: - Private Helpers

    private func findLocationRecord(id: String, in context: NSManagedObjectContext) -> CDLocationRecord? {
        let request = CDLocationRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findTripRecord(id: String, in context: NSManagedObjectContext) -> CDTripRecord? {
        let request = CDTripRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func findMinMaxRecord(in context: NSManagedObjectContext) -> CDMinMaxRecord? {
        let request = CDMinMaxRecord.fetchRequest()
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func saveBackground() {
        guard backgroundContext.hasChanges else { return }
        do {
            try backgroundContext.save()
        } catch {
            print("[CoreData] Background save failed: \(error)")
        }
    }
}
