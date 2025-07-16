import Foundation
import CloudKit
import SwiftUI

class CloudKitManager: ObservableObject {
    private let container: CKContainer
    private let database: CKDatabase
    
    @Published var isSignedInToiCloud = false
    @Published var error: String?
    
    init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
        
        getiCloudStatus()
        setupCloudKitSchema()
    }
    
    private func getiCloudStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
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
    }
    
    private func setupCloudKitSchema() {
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
        let ckRecord = record.toCKRecord()
        try await database.save(ckRecord)
    }
    
    func saveMinMaxRecord(_ record: MinMaxRecord) async throws {
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
        // Restore working query implementation
        do {
            return try await performCloudKitQuery()
        } catch {
            print("CloudKit query failed: \(error.localizedDescription)")
            // Return empty array to keep app functional
            return []
        }
    }
    
    private func performCloudKitQuery() async throws -> [LocationRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = CKQuery(recordType: "LocationRecord", predicate: NSPredicate(format: "TRUEPREDICATE"))
            let operation = CKQueryOperation(query: query)
            
            // Limit results to avoid potential issues with large datasets
            operation.resultsLimit = 100
            
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
    
    // Alternative approach: Track record IDs locally and fetch directly
    private func fetchRecordsById(_ recordIDs: [CKRecord.ID]) async throws -> [LocationRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            
            operation.fetchRecordsCompletionBlock = { recordsByID, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let recordsByID = recordsByID {
                    let records = recordsByID.values.compactMap { record in
                        LocationRecord.fromCKRecord(record)
                    }.sorted { $0.timestamp > $1.timestamp }
                    continuation.resume(returning: records)
                } else {
                    continuation.resume(returning: [])
                }
            }
            
            database.add(operation)
        }
    }
} 