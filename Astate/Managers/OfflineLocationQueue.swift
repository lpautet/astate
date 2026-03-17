import Foundation

class OfflineLocationQueue: ObservableObject {
    static let shared = OfflineLocationQueue()

    @Published var pendingCount: Int = 0

    private var records: [LocationRecord] = []
    private let queue = DispatchQueue(label: "com.astate.OfflineLocationQueue")
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pending_locations.plist")
    }()

    private init() {
        records = load()
        pendingCount = records.count
    }

    // MARK: - Public API

    func enqueue(_ record: LocationRecord) {
        queue.async { [self] in
            records.append(record)
            persist()
            let count = records.count
            DispatchQueue.main.async { self.pendingCount = count }
        }
    }

    /// Returns a snapshot of all pending records without removing them.
    func dequeueAll() -> [LocationRecord] {
        queue.sync { records }
    }

    /// Removes records with the given IDs (call after successful upload).
    func remove(ids: Set<String>) {
        queue.async { [self] in
            records.removeAll { ids.contains($0.id) }
            persist()
            let count = records.count
            DispatchQueue.main.async { self.pendingCount = count }
        }
    }

    // MARK: - Persistence

    private func load() -> [LocationRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? PropertyListDecoder().decode([LocationRecord].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
