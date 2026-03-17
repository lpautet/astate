import Foundation
import Network
import CoreTelephony
import SwiftUI

// MARK: - Connection Type

enum ConnectionType: String {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case none = "None"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .wifi:     return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .none:     return "wifi.slash"
        case .unknown:  return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .wifi:     return .green
        case .cellular: return .blue
        case .ethernet: return .cyan
        case .none:     return .red
        case .unknown:  return .gray
        }
    }
}

// MARK: - Network Change Entry

struct NetworkChangeEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let connectionType: ConnectionType
    let isConnected: Bool

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Network Interface

struct NetworkInterfaceInfo: Identifiable {
    let id = UUID()
    let name: String
    let typeName: String
}

// MARK: - NetworkMonitor

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    // Connectivity
    @Published var connectionType: ConnectionType = .unknown
    @Published var isConnected: Bool = false
    @Published var lastChanged: Date? = nil
    @Published var changeHistory: [NetworkChangeEntry] = []

    // Path details
    @Published var isExpensive: Bool = false
    @Published var isConstrained: Bool = false
    @Published var supportsIPv4: Bool = false
    @Published var supportsIPv6: Bool = false
    @Published var supportsDNS: Bool = false
    @Published var availableInterfaces: [NetworkInterfaceInfo] = []

    // Cellular details (nil when not on cellular)
    @Published var radioTechnology: String? = nil

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.astate.NetworkMonitor")
    private let maxHistoryEntries = 200

    private init() {
        LogManager.info("NetworkMonitor initialized", category: "Network")
        start()
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let newType = Self.connectionType(from: path)
            let connected = path.status == .satisfied

            DispatchQueue.main.async {
                // Always update path details (these can change independently)
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                self.supportsIPv4 = path.supportsIPv4
                self.supportsIPv6 = path.supportsIPv6
                self.supportsDNS = path.supportsDNS
                self.availableInterfaces = path.availableInterfaces.map {
                    NetworkInterfaceInfo(name: $0.name, typeName: Self.interfaceTypeName($0.type))
                }

                // Update cellular info when on cellular, clear otherwise
                if newType == .cellular {
                    self.updateCellularInfo()
                } else {
                    self.radioTechnology = nil
                }

                // Only log and record history when type or connectivity changes
                let previousType = self.connectionType
                let previousConnected = self.isConnected
                guard newType != previousType || connected != previousConnected else { return }

                self.connectionType = newType
                self.isConnected = connected
                self.lastChanged = Date()

                let status = connected ? "connected" : "disconnected"
                let message = "Network changed: \(newType.rawValue) (\(status))"

                if !connected {
                    LogManager.warning(message, category: "Network")
                } else if !previousConnected {
                    LogManager.info("Network restored: \(newType.rawValue)", category: "Network")
                } else {
                    LogManager.info(message, category: "Network")
                }

                let entry = NetworkChangeEntry(
                    timestamp: Date(),
                    connectionType: newType,
                    isConnected: connected
                )
                self.changeHistory.insert(entry, at: 0)
                if self.changeHistory.count > self.maxHistoryEntries {
                    self.changeHistory = Array(self.changeHistory.prefix(self.maxHistoryEntries))
                }
            }
        }

        monitor.start(queue: queue)
        LogManager.info("NetworkMonitor started", category: "Network")
    }

    func stop() {
        monitor.cancel()
        LogManager.info("NetworkMonitor stopped", category: "Network")
    }

    deinit {
        stop()
    }

    // MARK: - Helpers

    private static func connectionType(from path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi)          { return .wifi }
        if path.usesInterfaceType(.cellular)      { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .unknown
    }

    private static func interfaceTypeName(_ type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi:          return "Wi-Fi"
        case .cellular:      return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback:      return "Loopback"
        default:             return "Other"
        }
    }

    private func updateCellularInfo() {
        let info = CTTelephonyNetworkInfo()
        // Note: carrier name APIs deprecated in iOS 16 with no replacement
        if let services = info.serviceCurrentRadioAccessTechnology {
            let tech = services.values.first(where: { !$0.isEmpty })
            radioTechnology = tech.map { Self.readableRadioTech($0) }
        }
    }

    private static func readableRadioTech(_ tech: String) -> String {
        switch tech {
        case CTRadioAccessTechnologyNR:              return "5G NR"
        case CTRadioAccessTechnologyNRNSA:           return "5G NSA"
        case CTRadioAccessTechnologyLTE:             return "LTE (4G)"
        case CTRadioAccessTechnologyWCDMA:           return "WCDMA (3G)"
        case CTRadioAccessTechnologyHSDPA:           return "HSDPA (3G+)"
        case CTRadioAccessTechnologyHSUPA:           return "HSUPA (3G+)"
        case CTRadioAccessTechnologyCDMA1x:          return "CDMA 1x (2G)"
        case CTRadioAccessTechnologyCDMAEVDORev0:    return "CDMA EV-DO Rev 0"
        case CTRadioAccessTechnologyCDMAEVDORevA:    return "CDMA EV-DO Rev A"
        case CTRadioAccessTechnologyCDMAEVDORevB:    return "CDMA EV-DO Rev B"
        case CTRadioAccessTechnologyeHRPD:           return "eHRPD"
        case CTRadioAccessTechnologyGPRS:            return "GPRS (2G)"
        case CTRadioAccessTechnologyEdge:            return "EDGE (2G+)"
        default:                                     return tech
        }
    }
}
