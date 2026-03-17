import Foundation

final class CacheAwareDataManager: @unchecked Sendable {

    let cloudKitManager = CloudKitManager()
    private let coreData = CoreDataManager.shared

    private static let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
    private static let syncThrottle: TimeInterval = 5 * 60  // min seconds between syncs

    // MARK: - LocationRecord

    func saveLocationRecord(_ record: LocationRecord) async throws {
        await coreData.saveLocationRecord(record)
        try await cloudKitManager.saveLocationRecord(record)
    }

    /// Last 30 days: CoreData when cache is populated, CloudKit on first launch.
    func fetchLocationRecords() async throws -> [LocationRecord] {
        let since = Date().addingTimeInterval(-Self.thirtyDays)
        let cached = coreData.fetchLocationRecords(from: since, to: Date())
        if !cached.isEmpty { return cached }
        return try await cloudKitManager.fetchLocationRecords(since: since)
    }

    /// Last 24 h — always within 30-day window, serve from CoreData.
    func fetchLocationRecordsLast24Hours() async throws -> [LocationRecord] {
        let since = Date().addingTimeInterval(-24 * 60 * 60)
        let cached = coreData.fetchLocationRecords(from: since, to: Date())
        if !cached.isEmpty { return cached }
        return try await cloudKitManager.fetchLocationRecordsLast24Hours()
    }

    /// Last 7 days — always within 30-day window, serve from CoreData.
    func fetchLocationRecordsLastWeek() async throws -> [LocationRecord] {
        let since = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let cached = coreData.fetchLocationRecords(from: since, to: Date())
        if !cached.isEmpty { return cached }
        return try await cloudKitManager.fetchLocationRecordsLastWeek()
    }

    func fetchLocationRecords(since date: Date) async throws -> [LocationRecord] {
        let cutoff = Date().addingTimeInterval(-Self.thirtyDays)
        if date >= cutoff {
            let cached = coreData.fetchLocationRecords(from: date, to: Date())
            if !cached.isEmpty { return cached }
        }
        return try await cloudKitManager.fetchLocationRecords(since: date)
    }

    /// Route to CoreData for ranges within 30 days; fall back to CloudKit for older data.
    func fetchLocationRecords(from startDate: Date, to endDate: Date) async throws -> [LocationRecord] {
        let cutoff = Date().addingTimeInterval(-Self.thirtyDays)
        if startDate >= cutoff {
            let cached = coreData.fetchLocationRecords(from: startDate, to: endDate)
            if !cached.isEmpty { return cached }
        }
        return try await cloudKitManager.fetchLocationRecords(from: startDate, to: endDate)
    }

    // MARK: - TripRecord

    func saveTripRecord(_ trip: TripRecord) async throws {
        await coreData.saveTripRecord(trip)
        try await cloudKitManager.saveTripRecord(trip)
    }

    func fetchTripRecords() async throws -> [TripRecord] {
        let cached = coreData.fetchTripRecords()
        if !cached.isEmpty { return cached }
        return try await cloudKitManager.fetchTripRecords()
    }

    // MARK: - MinMaxRecord

    func saveMinMaxRecord(_ record: MinMaxRecord) async throws {
        await coreData.saveMinMaxRecord(record)
        try await cloudKitManager.saveMinMaxRecord(record)
    }

    func fetchMinMaxRecord() async throws -> MinMaxRecord? {
        if let cached = coreData.fetchMinMaxRecord() { return cached }
        return try await cloudKitManager.fetchMinMaxRecord()
    }

    // MARK: - Delta Sync

    func performDeltaSync() async {
        // Throttle: skip if synced recently
        if let last = coreData.lastSyncDate(for: .locationRecords),
           Date().timeIntervalSince(last) < Self.syncThrottle {
            return
        }

        await syncLocationRecords()
        await syncTripRecords()
        await syncMinMaxRecord()
        await coreData.pruneLocationRecordsOlderThan30Days()
    }

    private func syncLocationRecords() async {
        let since = coreData.lastSyncDate(for: .locationRecords) ?? .distantPast
        do {
            let records = try await cloudKitManager.fetchLocationRecords(since: since)
            if !records.isEmpty {
                await coreData.batchInsertLocationRecords(records)
            }
            coreData.setLastSyncDate(Date(), for: .locationRecords)
        } catch {
            print("[Sync] Location records sync failed: \(error)")
        }
    }

    private func syncTripRecords() async {
        // No date filter for trips (small dataset, ≤100); upsert by id handles duplicates.
        do {
            let trips = try await cloudKitManager.fetchTripRecords()
            if !trips.isEmpty {
                await coreData.batchInsertTripRecords(trips)
            }
            coreData.setLastSyncDate(Date(), for: .tripRecords)
        } catch {
            print("[Sync] Trip records sync failed: \(error)")
        }
    }

    private func syncMinMaxRecord() async {
        do {
            if let record = try await cloudKitManager.fetchMinMaxRecord() {
                await coreData.saveMinMaxRecord(record)
            }
            coreData.setLastSyncDate(Date(), for: .minMaxRecord)
        } catch {
            print("[Sync] MinMax record sync failed: \(error)")
        }
    }
}
