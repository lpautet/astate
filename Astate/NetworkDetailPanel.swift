import SwiftUI

// MARK: - Network Detail Panel

struct NetworkDetailPanel: View {
    @StateObject private var monitor = NetworkMonitor.shared
    @StateObject private var offlineQueue = OfflineLocationQueue.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    pathFlagsCard
                    if !monitor.availableInterfaces.isEmpty {
                        interfacesCard
                    }
                    if monitor.connectionType == .cellular {
                        cellularCard
                    }
                    offlineQueueCard
                    historyCard
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Network Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        NetworkInfoCard(title: "Current Status") {
            HStack(spacing: 14) {
                Image(systemName: monitor.connectionType.icon)
                    .foregroundColor(monitor.connectionType.color)
                    .font(.system(size: 30))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.connectionType.rawValue)
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(monitor.connectionType.color)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(monitor.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(monitor.isConnected ? "Connected" : "Disconnected")
                            .font(.subheadline)
                            .foregroundColor(monitor.isConnected ? .green : .red)
                    }
                }
                Spacer()
            }

            if let lastChanged = monitor.lastChanged {
                Divider().background(Color.gray.opacity(0.3)).padding(.vertical, 4)
                HStack {
                    Image(systemName: "clock").foregroundColor(.secondary).font(.caption)
                    Text("Last change").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lastChanged.formatted(date: .omitted, time: .standard))
                            .font(.caption).foregroundColor(.primary)
                        Text(relativeTime(for: lastChanged))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Path Flags Card

    private var pathFlagsCard: some View {
        NetworkInfoCard(title: "Path Details") {
            NetworkInfoRow(label: "Expensive", detail: "Cellular or hotspot",
                      value: monitor.isExpensive ? "Yes" : "No",
                      valueColor: monitor.isExpensive ? .orange : .green)
            NetworkDivider()
            NetworkInfoRow(label: "Low Data Mode", detail: nil,
                      value: monitor.isConstrained ? "On" : "Off",
                      valueColor: monitor.isConstrained ? .orange : .green)
            NetworkDivider()
            NetworkInfoRow(label: "IPv4", detail: nil,
                      value: monitor.supportsIPv4 ? "Supported" : "No",
                      valueColor: monitor.supportsIPv4 ? .green : .red)
            NetworkDivider()
            NetworkInfoRow(label: "IPv6", detail: nil,
                      value: monitor.supportsIPv6 ? "Supported" : "No",
                      valueColor: monitor.supportsIPv6 ? .green : .red)
            NetworkDivider()
            NetworkInfoRow(label: "DNS", detail: nil,
                      value: monitor.supportsDNS ? "Available" : "Unavailable",
                      valueColor: monitor.supportsDNS ? .green : .red)
        }
    }

    // MARK: - Interfaces Card

    private var interfacesCard: some View {
        NetworkInfoCard(title: "Active Interfaces") {
            ForEach(Array(monitor.availableInterfaces.enumerated()), id: \.element.id) { index, iface in
                if index > 0 { NetworkDivider() }
                HStack {
                    Text(iface.name)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(width: 60, alignment: .leading)
                    Text(iface.typeName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Cellular Card

    private var cellularCard: some View {
        NetworkInfoCard(title: "Cellular") {
            NetworkInfoRow(label: "Radio Technology", detail: nil,
                      value: monitor.radioTechnology ?? "Unknown",
                      valueColor: .blue)
        }
    }


    // MARK: - Offline Queue Card

    private var offlineQueueCard: some View {
        NetworkInfoCard(title: "Offline Queue") {
            HStack(spacing: 14) {
                Image(systemName: offlineQueue.pendingCount > 0 ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(offlineQueue.pendingCount > 0 ? .orange : .green)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 4) {
                    Text(offlineQueue.pendingCount > 0 ? "\(offlineQueue.pendingCount) record(s) pending" : "All synced")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(offlineQueue.pendingCount > 0 ? .orange : .green)
                    Text("Locations queued while offline")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - History Card

    private var historyCard: some View {
        NetworkInfoCard(title: "Change History") {
            if monitor.changeHistory.isEmpty {
                Text("No changes recorded yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(monitor.changeHistory.prefix(30).enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { NetworkDivider() }
                    HStack(spacing: 10) {
                        Image(systemName: entry.connectionType.icon)
                            .foregroundColor(entry.connectionType.color)
                            .font(.system(size: 13))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.connectionType.rawValue)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(entry.connectionType.color)
                            Text(entry.isConnected ? "Connected" : "Disconnected")
                                .font(.caption2)
                                .foregroundColor(entry.isConnected ? .green : .red)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.formattedTimestamp)
                                .font(.caption).foregroundColor(.primary)
                            Text(entry.relativeTime)
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Reusable Sub-Views

private struct NetworkInfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}

private struct NetworkInfoRow: View {
    let label: String
    let detail: String?
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if let detail = detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(value)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

private struct NetworkDivider: View {
    var body: some View {
        Divider()
            .background(Color.gray.opacity(0.25))
            .padding(.vertical, 2)
    }
}
