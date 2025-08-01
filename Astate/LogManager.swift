import Foundation
import SwiftUI

enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case warning = "WARNING"
    case critical = "CRITICAL"
    
    var color: Color {
        switch self {
        case .info:
            return .white
        case .warning:
            return .yellow
        case .critical:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .critical:
            return "xmark.octagon"
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let category: String
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

class LogManager: ObservableObject {
    @Published var logs: [LogEntry] = []
    private let maxLogEntries = 1000
    
    static let shared = LogManager()
    
    private init() {
        log(.info, "LogManager initialized", category: "System")
    }
    
    func log(_ level: LogLevel, _ message: String, category: String = "General") {
        DispatchQueue.main.async {
            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                message: message,
                category: category
            )
            
            self.logs.insert(entry, at: 0) // Add to beginning for newest first
            
            // Keep only the most recent entries
            if self.logs.count > self.maxLogEntries {
                self.logs = Array(self.logs.prefix(self.maxLogEntries))
            }
        }
        
        // Also print to console for debugging
        print("[\(level.rawValue)] [\(category)] \(message)")
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.log(.info, "Logs cleared", category: "System")
        }
    }
    
    func exportLogs() -> String {
        return logs.reversed().map { entry in
            "[\(entry.formattedTimestamp)] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

// Convenience functions for easier logging
extension LogManager {
    static func info(_ message: String, category: String = "General") {
        shared.log(.info, message, category: category)
    }
    
    static func warning(_ message: String, category: String = "General") {
        shared.log(.warning, message, category: category)
    }
    
    static func critical(_ message: String, category: String = "General") {
        shared.log(.critical, message, category: category)
    }
} 