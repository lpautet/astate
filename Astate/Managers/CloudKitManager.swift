import Foundation
import CloudKit
import SwiftUI

class CloudKitManager: ObservableObject {
    private let container: CKContainer
    private let database: CKDatabase
    private var hasCheckedStatus = false
    private var hasSetupSchema = false
    
    private var isSignedInToiCloud = false
    private var error: String?
    
    init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }
    
    private func checkiCloudStatusIfNeeded() {
        guard !hasCheckedStatus else { return }
        hasCheckedStatus = true
        
        container.accountStatus { [weak self] status, error in
            switch status {
            case .available:
                self?.isSignedInToiCloud = true
            case .noAccount:
                self?.error = "No iCloud account found"
            case .restricted:
                self?.error = "iCloud access restricted"
            case .couldNotDetermine:
                self?.error = "Unable to determine iCloud status"
            case .temporarilyUnavailable:
                self?.error = "iCloud services temporarily unavailable"
            @unknown default:
                self?.error = "Unknown iCloud status"
            }
        }
    }
    
    private func setupCloudKitSchemaIfNeeded() {
        guard !hasSetupSchema else { return }
        hasSetupSchema = true
        
        Task {
            do {
                try await createLocationRecordSchema()
                try await createMinMaxRecordSchema()
                print("CloudKit schema setup completed")
            } catch {
                print("CloudKit schema setup failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func ensureInitialized() {
        checkiCloudStatusIfNeeded()
        setupCloudKitSchemaIfNeeded()
    }
    
    private func createLocationRecordSchema() async throws {
        // Create LocationRecord schema with queryable fields
        let recordType = "LocationRecord"
        
        // Try to fetch schema to see if it exists
        do {
            let _ = try await database.record(for: CKRecord.ID(recordName: "schema-test-\(UUID().uuidString)"))
        } catch {
            // Expected to fail - we're just testing if the record type exists
        }
        
        // Create a sample record to establish the schema
        let sampleRecord = CKRecord(recordType: recordType)
        sampleRecord["timestamp"] = Date()
        sampleRecord["latitude"] = 0.0
        sampleRecord["longitude"] = 0.0
        sampleRecord["altitude"] = 0.0
        
        do {
            let _ = try await database.save(sampleRecord)
            // Delete the sample record after schema is created
            try await database.deleteRecord(withID: sampleRecord.recordID)
            print("LocationRecord schema created successfully")
        } catch {
            print("LocationRecord schema creation failed: \(error.localizedDescription)")
        }
    }
    
    private func createMinMaxRecordSchema() async throws {
        // Create MinMaxRecord schema
        let recordType = "MinMaxRecord"
        
        let sampleRecord = CKRecord(recordType: recordType)
        sampleRecord["lastUpdated"] = Date()
        sampleRecord["minAltitude"] = 0.0
        sampleRecord["maxAltitude"] = 0.0
        sampleRecord["minLatitude"] = 0.0
        sampleRecord["maxLatitude"] = 0.0
        sampleRecord["minLongitude"] = 0.0
        sampleRecord["maxLongitude"] = 0.0
        
        do {
            let _ = try await database.save(sampleRecord)
            // Delete the sample record after schema is created
            try await database.deleteRecord(withID: sampleRecord.recordID)
            print("MinMaxRecord schema created successfully")
        } catch {
            print("MinMaxRecord schema creation failed: \(error.localizedDescription)")
        }
    }
    
    func saveLocationRecord(_ record: LocationRecord) async throws {
        ensureInitialized()
        let ckRecord = record.toCKRecord()
        try await database.save(ckRecord)
    }
    
    func saveMinMaxRecord(_ record: MinMaxRecord) async throws {
        ensureInitialized()
        let recordID = CKRecord.ID(recordName: "minmax-singleton")
        
        do {
            // Try to fetch existing record first
            let existingRecord = try await database.record(for: recordID)
            
            // Update existing record with new values
            existingRecord["lastUpdated"] = record.lastUpdated
            existingRecord["minAltitude"] = record.minAltitude
            existingRecord["maxAltitude"] = record.maxAltitude
            existingRecord["minLatitude"] = record.minLatitude
            existingRecord["maxLatitude"] = record.maxLatitude
            existingRecord["minLongitude"] = record.minLongitude
            existingRecord["maxLongitude"] = record.maxLongitude
            
            try await database.save(existingRecord)
            
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist, create new one
            let ckRecord = record.toCKRecord()
            try await database.save(ckRecord)
        }
    }
    
    func fetchMinMaxRecord() async throws -> MinMaxRecord? {
        ensureInitialized()
        let recordID = CKRecord.ID(recordName: "minmax-singleton")
        do {
            let ckRecord = try await database.record(for: recordID)
            return MinMaxRecord.fromCKRecord(ckRecord)
        } catch let error as CKError where error.code == .unknownItem {
            // No existing record, return nil
            return nil
        }
    }
    
    func fetchLocationRecords() async throws -> [LocationRecord] {
        ensureInitialized()
        // Restore working query implementation
        do {
            return try await performCloudKitQuery()
        } catch {
            print("CloudKit query failed: \(error.localizedDescription)")
            // Return empty array to keep app functional
            return []
        }
    }
    
    func fetchLocationRecordsLast24Hours() async throws -> [LocationRecord] {
        ensureInitialized()
        do {
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
            return try await performTimeBasedQueryWithPagination(since: oneDayAgo)
        } catch {
            print("CloudKit 24h query failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchLocationRecordsLastWeek() async throws -> [LocationRecord] {
        ensureInitialized()
        do {
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
            return try await performTimeBasedQueryWithPagination(since: oneWeekAgo)
        } catch {
            print("CloudKit week query failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchLocationRecords(since date: Date) async throws -> [LocationRecord] {
        ensureInitialized()
        do {
            return try await performTimeBasedQueryWithPagination(since: date)
        } catch {
            print("CloudKit custom range query failed: \(error.localizedDescription)")
            return []
        }
    }
    
    private func performCloudKitQuery() async throws -> [LocationRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = CKQuery(recordType: "LocationRecord", predicate: NSPredicate(format: "TRUEPREDICATE"))
            // Sort by timestamp descending to get the most recent records first
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            let operation = CKQueryOperation(query: query)
            
            // Set to CloudKit's maximum allowed limit per request to get the most recent 400 records
            operation.resultsLimit = 400
            
            var records: [LocationRecord] = []
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let locationRecord = LocationRecord.fromCKRecord(record) {
                        records.append(locationRecord)
                    }
                case .failure(let error):
                    print("Error fetching individual record: \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    // Sort locally by timestamp (most recent first)
                    let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                    continuation.resume(returning: sortedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    private func performTimeBasedQueryWithPagination(since date: Date) async throws -> [LocationRecord] {
        var allRecords: [LocationRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil
        var hasMoreResults = true
        
        while hasMoreResults {
            let batchRecords = try await performTimeBasedQueryBatch(since: date, cursor: cursor)
            allRecords.append(contentsOf: batchRecords.records)
            
            cursor = batchRecords.cursor
            hasMoreResults = cursor != nil
            
            print("Fetched \(batchRecords.records.count) records, total: \(allRecords.count)")
        }
        
        // Sort all results by timestamp (most recent first)
        let sortedRecords = allRecords.sorted { $0.timestamp > $1.timestamp }
        print("📊 Fetched \(sortedRecords.count) records from last 24 hours")
        return sortedRecords
    }
    
    private func performTimeBasedQueryBatch(since date: Date, cursor: CKQueryOperation.Cursor?) async throws -> (records: [LocationRecord], cursor: CKQueryOperation.Cursor?) {
        return try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            
            if let cursor = cursor {
                // Continue pagination with cursor
                operation = CKQueryOperation(cursor: cursor)
            } else {
                // Initial query with time-based predicate
                let predicate = NSPredicate(format: "timestamp >= %@", date as NSDate)
                let query = CKQuery(recordType: "LocationRecord", predicate: predicate)
                query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                operation = CKQueryOperation(query: query)
            }
            
            // Set limit per batch (CloudKit max is 400)
            operation.resultsLimit = 400
            
            var records: [LocationRecord] = []
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let locationRecord = LocationRecord.fromCKRecord(record) {
                        records.append(locationRecord)
                    }
                case .failure(let error):
                    print("Error fetching individual record: \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (records: records, cursor: cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.database.add(operation)
        }
    }
    
    // Alternative approach: Track record IDs locally and fetch directly
    private func fetchRecordsById(_ recordIDs: [CKRecord.ID]) async throws -> [LocationRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            var records: [LocationRecord] = []
            
            operation.perRecordResultBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let locationRecord = LocationRecord.fromCKRecord(record) {
                        records.append(locationRecord)
                    }
                case .failure(let error):
                    print("Error fetching record \(recordID): \(error)")
                }
            }
            
            operation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
                    continuation.resume(returning: sortedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
} 
