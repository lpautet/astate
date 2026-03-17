//
//  ContentView.swift
//  Astate
//
//  Created by Laurent Pautet on 11/05/2025.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Charts

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var globalLocationManager = LocationManager()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineQueue = OfflineLocationQueue.shared
    
    var body: some View {
        TabView {
            TrackingTabView(locationManager: globalLocationManager)
                .tabItem {
                    Image(systemName: "map")
                    Text("Tracking")
                }
            
            LocationTabView(locationManager: globalLocationManager)
                .tabItem {
                    Image(systemName: "location")
                    Text("Location")
                }
            
            MotionTabView()
                .tabItem {
                    Image(systemName: "move.3d")
                    Text("Motion")
                }
            
            CompassTabView()
                .tabItem {
                    Image(systemName: "compass.drawing")
                    Text("Compass")
                }
            
            LogsTabView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Logs")
                }
                .badge(offlineQueue.pendingCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // App going to background - switch to battery efficient mode
            LogManager.info("App going to background", category: "System")
            globalLocationManager.setHighPrecisionMode(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // App returning to foreground - precision will be set by individual tabs
            LogManager.info("App became active", category: "System")
        }
        .overlay(alignment: .top) {
            if !networkMonitor.isConnected {
                NetworkOfflineBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: networkMonitor.isConnected)
    }
}

// MARK: - Location Tab View
struct LocationTabView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var barometerManager = BarometerManager()
    @StateObject private var weatherManager = WeatherManager()
    @StateObject private var parkingManager = ParkingManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LocationDataSectionView(manager: locationManager)
                    
                    // High precision mode indicator
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("High precision mode (1m accuracy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    CurrentLocationMapView(locationManager: locationManager,
                                          parkingLocation: parkingManager.parkingLocation)
                    
                    if barometerManager.isAvailable {
                        BarometerSectionView(manager: barometerManager)
                    }
                    
                    WeatherSectionView(weatherManager: weatherManager)
                    
                    ParkingSectionView(parkingManager: parkingManager,
                                       locationManager: locationManager)
                }
                .padding()
            }
            .navigationTitle("Current Location")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NetworkStatusToolbarItem()
                }
            }
            .onAppear {
                LogManager.info("Location tab opened", category: "UI")
                locationManager.startUpdatingLocation()
                locationManager.setHighPrecisionMode(true) // 1.0m for real-time viewing
                if barometerManager.isAvailable {
                    barometerManager.startUpdates()
                }
                if let loc = locationManager.location {
                    weatherManager.fetchIfNeeded(for: loc)
                }
            }
            .onChange(of: locationManager.location) { _, newLocation in
                if let loc = newLocation {
                    weatherManager.fetchIfNeeded(for: loc)
                }
            }
            .onDisappear {
                locationManager.setHighPrecisionMode(false) // Back to 10.0m for battery efficiency
                locationManager.stopUpdatingLocation()
                barometerManager.stopUpdates()
            }
        }
    }
}

// MARK: - Tracking Tab View
struct TrackingTabView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var selectedTimeRange: TimeRange = .lastMonth
    @StateObject private var heatmapManager = HeatmapManager()
    @State private var showHeatmap = false
    @State private var showTripHistory = false
    @State private var tripName = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    RecordingControlsView(manager: locationManager,
                                          showTripHistory: $showTripHistory)
                    
                    LocationMapView(locationManager: locationManager,
                                    selectedTimeRange: $selectedTimeRange,
                                    showHeatmap: showHeatmap,
                                    heatmapCells: heatmapManager.cells,
                                    onRecordsLoaded: { records in
                                        heatmapManager.buildHeatmap(from: records)
                                    },
                                    showHeatmapToggle: $showHeatmap)
                    
                    MinMaxValuesSectionView(manager: locationManager)
                    
                    TripAnalysisSectionView(locationManager: locationManager, selectedTimeRange: $selectedTimeRange)
                }
                .padding()
            }
            .navigationTitle("Location Tracking")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NetworkStatusToolbarItem()
                }
            }
            .onAppear {
                LogManager.info("Tracking tab opened", category: "UI")
                locationManager.startUpdatingLocation()
                locationManager.setHighPrecisionMode(false)
            }
            .onDisappear {
                locationManager.stopUpdatingLocation()
            }
            .sheet(isPresented: $showTripHistory) {
                TripHistoryView(dataManager: locationManager.dataManager)
            }
            .sheet(isPresented: $locationManager.showTripSavePrompt) {
                TripSaveSheet(locationManager: locationManager,
                               tripName: $tripName,
                               selectedTimeRange: selectedTimeRange)
            }
        }
    }
}

// MARK: - Motion Tab View
struct MotionTabView: View {
    @StateObject private var accelerometerManager = AccelerometerManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AccelerometerValuesSectionView(manager: accelerometerManager)
                }
                .padding()
            }
            .navigationTitle("Motion")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NetworkStatusToolbarItem()
                }
            }
            .onAppear {
                accelerometerManager.startUpdates()
            }
            .onDisappear {
                accelerometerManager.stopUpdates()
            }
        }
    }
}

// MARK: - Compass Tab View
struct CompassTabView: View {
    @StateObject private var magnetometerManager = MagnetometerManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if magnetometerManager.isAvailable {
                        MagnetometerSectionView(manager: magnetometerManager)
                    } else {
                        UnavailableSensorView(
                            sensorName: "Magnetometer",
                            description: "Magnetic field sensor is not available on this device"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Compass")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NetworkStatusToolbarItem()
                }
            }
            .onAppear {
                if magnetometerManager.isAvailable {
                    magnetometerManager.startUpdates()
                }
            }
            .onDisappear {
                magnetometerManager.stopUpdates()
            }
        }
    }
}

// MARK: - Logs Tab View
struct LogsTabView: View {
    @StateObject private var logManager = LogManager.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var selectedCategory: String? = nil
    @State private var showingShareSheet = false
    
    var filteredLogs: [LogEntry] {
        var logs = logManager.logs
        
        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }
        
        if let category = selectedCategory {
            logs = logs.filter { $0.category == category }
        }
        
        return logs
    }
    
    var availableCategories: [String] {
        Array(Set(logManager.logs.map { $0.category })).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                LogFilterControlsView(
                    selectedLevel: $selectedLevel,
                    selectedCategory: $selectedCategory,
                    availableCategories: availableCategories
                )
                
                LogsListView(filteredLogs: filteredLogs)
            }
            .background(Color.black)
            .navigationTitle("Activity Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NetworkStatusToolbarItem()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export Logs") {
                            showingShareSheet = true
                        }
                        Button("Clear All Logs") {
                            logManager.clearLogs()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(activityItems: [logManager.exportLogs()])
            }
        }
        .onAppear {
            LogManager.info("Logs tab opened", category: "UI")
        }
    }
}

// MARK: - Network Status Views

struct NetworkStatusToolbarItem: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineQueue = OfflineLocationQueue.shared
    @State private var showPanel = false

    var body: some View {
        Button {
            showPanel = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: networkMonitor.connectionType.icon)
                    .foregroundColor(networkMonitor.connectionType.color)
                    .font(.system(size: 14, weight: .medium))
                Text(networkMonitor.connectionType.rawValue)
                    .font(.caption2)
                    .foregroundColor(networkMonitor.connectionType.color)
                if offlineQueue.pendingCount > 0 {
                    Text("\(offlineQueue.pendingCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .animation(.easeInOut(duration: 0.3), value: networkMonitor.connectionType)
        }
        .sheet(isPresented: $showPanel) {
            NetworkDetailPanel()
        }
    }
}

struct NetworkOfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("No Internet Connection")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.92))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}

// MARK: - Log Filter Controls View
struct LogFilterControlsView: View {
    @Binding var selectedLevel: LogLevel?
    @Binding var selectedCategory: String?
    let availableCategories: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            LogLevelFilterView(selectedLevel: $selectedLevel)
            LogCategoryFilterView(selectedCategory: $selectedCategory, availableCategories: availableCategories)
        }
        .padding()
        .background(Color.black.opacity(0.9))
    }
}

// MARK: - Log Level Filter View
struct LogLevelFilterView: View {
    @Binding var selectedLevel: LogLevel?
    
    var body: some View {
        HStack {
            Text("Level:")
                .foregroundColor(.white)
                .font(.caption)
            
            ForEach(LogLevel.allCases, id: \.self) { level in
                LogLevelButtonView(level: level, selectedLevel: $selectedLevel)
            }
            
            Spacer()
            
            Button("Clear") {
                selectedLevel = nil
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
    }
}

// MARK: - Log Level Button View
struct LogLevelButtonView: View {
    let level: LogLevel
    @Binding var selectedLevel: LogLevel?
    
    private var isSelected: Bool {
        selectedLevel == level
    }
    
    private var backgroundColor: Color {
        isSelected ? level.color.opacity(0.3) : Color.gray.opacity(0.2)
    }
    
    private var foregroundColor: Color {
        isSelected ? level.color : .white
    }
    
    var body: some View {
        Button(action: {
            selectedLevel = selectedLevel == level ? nil : level
        }) {
            HStack(spacing: 4) {
                Image(systemName: level.icon)
                    .font(.caption)
                Text(level.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
        }
    }
}

// MARK: - Log Category Filter View
struct LogCategoryFilterView: View {
    @Binding var selectedCategory: String?
    let availableCategories: [String]
    
    var body: some View {
        HStack {
            Text("Category:")
                .foregroundColor(.white)
                .font(.caption)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(availableCategories, id: \.self) { category in
                        LogCategoryButtonView(category: category, selectedCategory: $selectedCategory)
                    }
                }
            }
            
            Spacer()
            
            Button("Clear") {
                selectedCategory = nil
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
    }
}

// MARK: - Log Category Button View
struct LogCategoryButtonView: View {
    let category: String
    @Binding var selectedCategory: String?
    
    private var isSelected: Bool {
        selectedCategory == category
    }
    
    private var backgroundColor: Color {
        isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2)
    }
    
    private var foregroundColor: Color {
        isSelected ? .blue : .white
    }
    
    var body: some View {
        Button(category) {
            selectedCategory = selectedCategory == category ? nil : category
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(4)
    }
}

// MARK: - Logs List View
struct LogsListView: View {
    let filteredLogs: [LogEntry]
    
    var body: some View {
        if filteredLogs.isEmpty {
            Spacer()
            VStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("No logs available")
                    .foregroundColor(.gray)
                    .font(.headline)
                Text("App activity will appear here")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            Spacer()
        } else {
            List(filteredLogs) { entry in
                LogEntryRowView(entry: entry)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Log Entry Row View
struct LogEntryRowView: View {
    let entry: LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.level.icon)
                    .foregroundColor(entry.level.color)
                    .font(.caption)
                
                Text(entry.level.rawValue)
                    .foregroundColor(entry.level.color)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(entry.category)
                    .foregroundColor(.gray)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(3)
                
                Spacer()
                
                Text(entry.formattedTimestamp)
                    .foregroundColor(.gray)
                    .font(.caption)
                    .monospacedDigit()
            }
            
            Text(entry.message)
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(6)
    }
}

// MARK: - Activity View Controller
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Unavailable Sensor View
struct UnavailableSensorView: View {
    let sensorName: String
    let description: String
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Sensor Unavailable")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(sensorName)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
    }
}

// MARK: - Location Data Section View
struct LocationDataSectionView: View {
    @ObservedObject var manager: LocationManager
    @State private var currentAddress: String?
    @State private var isGeocodingAddress = false
    @State private var lastGeocodedLocation: CLLocation?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location Data")
                .font(.headline)
            
            VStack(spacing: 10) {
                LocationDataRow(
                    title: "Latitude",
                    value: manager.location?.coordinate.latitude ?? 0,
                    accuracy: manager.location?.horizontalAccuracy ?? 0
                )
                LocationDataRow(
                    title: "Longitude",
                    value: manager.location?.coordinate.longitude ?? 0,
                    accuracy: manager.location?.horizontalAccuracy ?? 0
                )
                LocationDataRow(
                    title: "Altitude",
                    value: manager.location?.altitude ?? 0,
                    accuracy: manager.location?.verticalAccuracy ?? 0,
                    unit: "m"
                )
                LocationDataRow(
                    title: "Speed",
                    value: manager.speed,
                    accuracy: manager.speedAccuracy,
                    unit: "m/s"
                )
                
                HStack {
                    Text("Authorization")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(authorizationStatusText(manager.authorizationStatus))
                        .foregroundColor(authorizationStatusColor(manager.authorizationStatus))
                        .font(.caption)
                }

                HStack {
                    Text("Address")
                        .foregroundColor(.secondary)
                    Spacer()
                    if isGeocodingAddress {
                        ProgressView().scaleEffect(0.7)
                    } else if let address = currentAddress {
                        Text(address)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = address
                                } label: {
                                    Label("Copy Address", systemImage: "doc.on.doc")
                                }
                            }
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .onChange(of: manager.location) { _, newLocation in
            reverseGeocodeIfNeeded(newLocation)
        }
        .onAppear {
            reverseGeocodeIfNeeded(manager.location)
        }
    }

    private func reverseGeocodeIfNeeded(_ location: CLLocation?) {
        guard let location else { return }
        let threshold: CLLocationDistance = 50
        if let last = lastGeocodedLocation, location.distance(from: last) < threshold { return }
        lastGeocodedLocation = location
        isGeocodingAddress = true
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            DispatchQueue.main.async {
                isGeocodingAddress = false
                if let p = placemarks?.first {
                    var parts: [String] = []
                    if let number = p.subThoroughfare { parts.append(number) }
                    if let street = p.thoroughfare {
                        parts.append(street)
                    } else if let subLocality = p.subLocality {
                        parts.append(subLocality)
                    } else if let area = p.administrativeArea {
                        parts.append(area)
                    }
                    if let city = p.locality { parts.append(city) }
                    currentAddress = parts.isEmpty ? p.country : parts.joined(separator: ", ")
                }
            }
        }
    }
}

// MARK: - Min/Max Values Section View
struct MinMaxValuesSectionView: View {
    @ObservedObject var manager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Min/Max Values")
                .font(.headline)
            
            Group {
                MinMaxRow(title: "Altitude",
                         min: manager.minAltitude,
                         max: manager.maxAltitude,
                         unit: "m")
                MinMaxRow(title: "Latitude",
                         min: manager.minLatitude,
                         max: manager.maxLatitude)
                MinMaxRow(title: "Longitude",
                         min: manager.minLongitude,
                         max: manager.maxLongitude)
                MinMaxRow(title: "Speed",
                         min: manager.minSpeed,
                         max: manager.maxSpeed,
                         unit: "m/s")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

// MARK: - Recording Controls View
struct RecordingControlsView: View {
    @ObservedObject var manager: LocationManager
    @Binding var showTripHistory: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            Button(action: {
                if manager.isRecording {
                    manager.stopRecording()
                } else {
                    manager.startRecording()
                }
            }) {
                Text(manager.isRecording ? "Stop Recording" : "Start Recording")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manager.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if manager.isRecording {
                VStack(spacing: 2) {
                    Text("Recording location data every minute (including background)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Only saves when moved 5+ meters")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { showTripHistory = true }) {
                Label("Trip History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Accelerometer Values Section View
struct AccelerometerValuesSectionView: View {
    @ObservedObject var manager: AccelerometerManager
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Accelerometer Values")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                AccelerometerView(axis1: manager.x, axis2: manager.y, title: "X-Y")
                AccelerometerView(axis1: manager.x, axis2: manager.z, title: "X-Z")
                AccelerometerView(axis1: manager.y, axis2: manager.z, title: "Y-Z")
            }
            .padding(.vertical)
            
            VStack(spacing: 10) {
                AccelerometerValueView(title: "X-Axis", value: manager.x)
                AccelerometerValueView(title: "Y-Axis", value: manager.y)
                AccelerometerValueView(title: "Z-Axis", value: manager.z)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
    }
}

// MARK: - Magnetometer Section View
struct MagnetometerSectionView: View {
    @ObservedObject var manager: MagnetometerManager
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Magnetic Field")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                HStack {
                    Text("Heading")
                        .font(.headline)
                        .frame(width: 80, alignment: .leading)
                    
                    Text("\(String(format: "%.1f°", manager.heading)) \(manager.cardinalDirection)")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack {
                    Text("Strength")
                        .font(.headline)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(String(format: "%.1f µT", manager.totalFieldStrength))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                
                Text("Components")
                    .font(.headline)
                
                AccelerometerValueView(title: "X-Axis", value: manager.x)
                AccelerometerValueView(title: "Y-Axis", value: manager.y)
                AccelerometerValueView(title: "Z-Axis", value: manager.z)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
    }
}

// MARK: - Barometer Section View
struct BarometerSectionView: View {
    @ObservedObject var manager: BarometerManager
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Atmospheric Pressure")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                HStack {
                    Text("Pressure")
                        .font(.headline)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(String(format: "%.1f hPa", manager.pressureInHectopascals))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack {
                    Text("Altitude")
                        .font(.headline)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(String(format: "%.1f m", manager.relativeAltitude))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
    }
}

// MARK: - Supporting Views
struct AccelerometerValueView: View {
    let title: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .frame(width: 80, alignment: .leading)
            
            Text(String(format: "%.4f", value))
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LocationDataRow: View {
    let title: String
    let value: Double
    let accuracy: Double
    var unit: String = ""
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.6f", value) + (unit.isEmpty ? "" : " \(unit)"))
                .monospacedDigit()
            Text("(±\(String(format: "%.1f", accuracy)))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MinMaxRow: View {
    let title: String
    let min: Double
    let max: Double
    var unit: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .foregroundColor(.secondary)
            HStack {
                Text("Min: \(String(format: "%.6f", min))\(unit.isEmpty ? "" : " \(unit)")")
                    .monospacedDigit()
                Spacer()
                Text("Max: \(String(format: "%.6f", max))\(unit.isEmpty ? "" : " \(unit)")")
                    .monospacedDigit()
            }
            .font(.caption)
        }
    }
}

// MARK: - Helper Functions
private func authorizationStatusText(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
        return "Not Determined"
    case .restricted:
        return "Restricted"
    case .denied:
        return "Denied"
    case .authorizedAlways:
        return "Always"
    case .authorizedWhenInUse:
        return "When In Use"
    @unknown default:
        return "Unknown"
    }
}

private func authorizationStatusColor(_ status: CLAuthorizationStatus) -> Color {
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
        return .green
    case .denied, .restricted:
        return .red
    case .notDetermined:
        return .orange
    @unknown default:
        return .gray
    }
}

// MARK: - Map Coordinate Decimation

/// Reduces a dense array of location records to a visually representative set of
/// coordinates by skipping any point closer than `minDistance` metres to the last
/// kept point. Processes records in chronological order (oldest-first).
/// This collapses stationary clusters (e.g. parked overnight) to a single point
/// while preserving the shape of the travelled path.
private func decimateCoordinates(_ records: [LocationRecord], minDistance: CLLocationDistance) -> [CLLocationCoordinate2D] {
    guard records.count > 1 else {
        return records.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
    // Records are newest-first; reverse to process in travel order
    let ordered = records.reversed()
    var result: [CLLocationCoordinate2D] = []
    var lastKept: CLLocation?
    for record in ordered {
        let loc = CLLocation(latitude: record.latitude, longitude: record.longitude)
        if let last = lastKept, loc.distance(from: last) < minDistance { continue }
        result.append(CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude))
        lastKept = loc
    }
    // Always include the very last (newest) point
    if let newest = records.first {
        let newestCoord = CLLocationCoordinate2D(latitude: newest.latitude, longitude: newest.longitude)
        if result.last.map({ $0.latitude != newestCoord.latitude || $0.longitude != newestCoord.longitude }) ?? true {
            result.append(newestCoord)
        }
    }
    return result
}

// MARK: - Location Map View
enum TimeRange: String, CaseIterable {
    case lastMonth = "Last Month"
    case last24Hours = "Last 24 Hours"
    case lastWeek = "Last Week"
    
    var description: String {
        switch self {
        case .lastMonth: return "All records from last 30 days"
        case .last24Hours: return "All records from last 24 hours"
        case .lastWeek: return "All records from last 7 days"
        }
    }
}

// MARK: - Trip Analysis Data Types

struct TripStats {
    let totalDistanceMeters: Double
    let elevationGainMeters: Double
    let elevationLossMeters: Double
    let durationSeconds: TimeInterval
    let averageSpeedMps: Double
    let pointCount: Int
    
    static let empty = TripStats(
        totalDistanceMeters: 0,
        elevationGainMeters: 0,
        elevationLossMeters: 0,
        durationSeconds: 0,
        averageSpeedMps: 0,
        pointCount: 0
    )
}

struct ElevationPoint: Identifiable {
    let id = UUID()
    let cumulativeDistanceKm: Double
    let altitudeMeters: Double
}

struct SpeedPoint: Identifiable {
    let id = UUID()
    let cumulativeDistanceKm: Double
    let speedKph: Double
}

private func computeTripStats(from records: [LocationRecord]) -> TripStats {
    guard records.count >= 2 else {
        return TripStats(
            totalDistanceMeters: 0,
            elevationGainMeters: 0,
            elevationLossMeters: 0,
            durationSeconds: 0,
            averageSpeedMps: 0,
            pointCount: records.count
        )
    }
    
    let sorted = records.sorted { $0.timestamp < $1.timestamp }
    var totalDistance: Double = 0
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    
    for i in 1..<sorted.count {
        let prev = sorted[i - 1]
        let curr = sorted[i]
        let prevLocation = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
        let currLocation = CLLocation(latitude: curr.latitude, longitude: curr.longitude)
        totalDistance += currLocation.distance(from: prevLocation)
        
        let altDelta = curr.altitude - prev.altitude
        if altDelta > 0 {
            elevationGain += altDelta
        } else {
            elevationLoss += -altDelta
        }
    }
    
    let duration = sorted.last!.timestamp.timeIntervalSince(sorted.first!.timestamp)
    let avgSpeed = duration > 0 ? totalDistance / duration : 0
    
    return TripStats(
        totalDistanceMeters: totalDistance,
        elevationGainMeters: elevationGain,
        elevationLossMeters: elevationLoss,
        durationSeconds: duration,
        averageSpeedMps: avgSpeed,
        pointCount: sorted.count
    )
}

private func buildChartData(from records: [LocationRecord]) -> ([ElevationPoint], [SpeedPoint]) {
    guard records.count >= 2 else { return ([], []) }
    
    let sorted = records.sorted { $0.timestamp < $1.timestamp }
    var elevationPoints: [ElevationPoint] = []
    var speedPoints: [SpeedPoint] = []
    var cumulativeDistanceKm: Double = 0
    
    elevationPoints.append(ElevationPoint(cumulativeDistanceKm: 0, altitudeMeters: sorted[0].altitude))
    speedPoints.append(SpeedPoint(cumulativeDistanceKm: 0, speedKph: 0))
    
    for i in 1..<sorted.count {
        let prev = sorted[i - 1]
        let curr = sorted[i]
        let prevLocation = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
        let currLocation = CLLocation(latitude: curr.latitude, longitude: curr.longitude)
        let distance = currLocation.distance(from: prevLocation)
        cumulativeDistanceKm += distance / 1000.0
        
        elevationPoints.append(ElevationPoint(cumulativeDistanceKm: cumulativeDistanceKm, altitudeMeters: curr.altitude))
        
        let timeDelta = curr.timestamp.timeIntervalSince(prev.timestamp)
        let speedMps = timeDelta > 0 ? distance / timeDelta : 0
        let speedKph = min(speedMps * 3.6, 250.0)
        speedPoints.append(SpeedPoint(cumulativeDistanceKm: cumulativeDistanceKm, speedKph: speedKph))
    }
    
    return (elevationPoints, speedPoints)
}

struct LocationMapView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedTimeRange: TimeRange
    var showHeatmap: Bool = false
    var heatmapCells: [HeatmapCell] = []
    var onRecordsLoaded: (([LocationRecord]) -> Void)? = nil
    @Binding var showHeatmapToggle: Bool
    @State private var locationRecords: [LocationRecord] = []
    @State private var displayCoordinates: [CLLocationCoordinate2D] = []
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showFullscreenMap = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 8) {
                HStack {
                    Text("Recorded Locations")
                        .font(.headline)
                    if locationManager.isRecording {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("Recording")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Button(action: { showHeatmapToggle.toggle() }) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(showHeatmap ? .orange : .secondary)
                    }
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if errorMessage != nil {
                        Text("Error")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("\(locationRecords.count) points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Time Range:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedTimeRange) { _, _ in
                        loadLocationRecords()
                    }
                }
                
                if selectedTimeRange != .lastMonth {
                    Text(selectedTimeRange.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let error = errorMessage {
                VStack {
                    Text("Unable to load location data")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else if locationRecords.isEmpty && !isLoading {
                VStack {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recorded locations yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Start recording to see your path on the map")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                Map(position: $mapCameraPosition) {
                    if displayCoordinates.count > 1 {
                        MapPolyline(coordinates: displayCoordinates)
                            .stroke(.blue, lineWidth: 2)
                    }
                    if let oldest = locationRecords.last {
                        Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: oldest.latitude, longitude: oldest.longitude)) {
                            Image(systemName: "flag.circle.fill")
                                .foregroundColor(.green)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    if let newest = locationRecords.first {
                        Annotation("Latest", coordinate: CLLocationCoordinate2D(latitude: newest.latitude, longitude: newest.longitude)) {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    if showHeatmap {
                        ForEach(heatmapCells) { cell in
                            MapCircle(center: cell.coordinate, radius: 80)
                                .foregroundStyle(
                                    HeatmapManager.color(for: cell.normalizedIntensity)
                                        .opacity(0.3 + 0.4 * cell.normalizedIntensity)
                                )
                        }
                    }
                }
                .frame(height: 250)
                .cornerRadius(10)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                }
                .onTapGesture { showFullscreenMap = true }
                .fullScreenCover(isPresented: $showFullscreenMap) {
                    FullscreenLocationMapView(
                        locationRecords: locationRecords,
                        showHeatmap: showHeatmap,
                        heatmapCells: heatmapCells
                    )
                }
            }
            
            HStack {
                if !locationRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest: \(formatDate(locationRecords.first?.timestamp ?? Date()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Oldest: \(formatDate(locationRecords.last?.timestamp ?? Date()))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(isLoading ? "Loading..." : "Refresh") {
                    loadLocationRecords()
                }
                .font(.caption)
                .disabled(isLoading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .onAppear {
            loadLocationRecords()
        }
        .onChange(of: locationManager.lastLocationSaved) { _, _ in
            // Auto-refresh map when new location data is saved
            if locationManager.isRecording {
                loadLocationRecords()
            }
        }
    }
    
    private func loadLocationRecords() {
        Task {
            // Defer all state changes to avoid modifying state during view update
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            do {
                let records: [LocationRecord]
                let fetchStart = Date()
                
                switch selectedTimeRange {
                case .lastMonth:
                    records = try await locationManager.dataManager.fetchLocationRecords(since: Calendar.current.date(byAdding: .day, value: -30, to: Date())!)
                case .last24Hours:
                    records = try await locationManager.dataManager.fetchLocationRecordsLast24Hours()
                case .lastWeek:
                    records = try await locationManager.dataManager.fetchLocationRecordsLastWeek()
                }
                
                await MainActor.run {
                    self.locationRecords = records
                    self.displayCoordinates = decimateCoordinates(records, minDistance: 50)
                    self.isLoading = false
                    self.errorMessage = nil
                    
                    // Update map region to fit all recorded locations
                    if !records.isEmpty {
                        self.mapCameraPosition = .region(self.calculateMapRegion(for: records))
                    }
                    
                    self.onRecordsLoaded?(records)
                    let elapsed = Date().timeIntervalSince(fetchStart)
                    LogManager.info("Loaded \(records.count) records for \(selectedTimeRange.rawValue) in \(String(format: "%.2f", elapsed))s", category: "Map")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
                LogManager.warning("Error loading location records: \(error.localizedDescription)", category: "Map")
            }
        }
    }
    
    private func calculateMapRegion(for records: [LocationRecord]) -> MKCoordinateRegion {
        guard !records.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // If only one point, center on it with default zoom
        if records.count == 1 {
            let record = records[0]
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Calculate bounding box for multiple points
        let latitudes = records.map { $0.latitude }
        let longitudes = records.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        // Calculate center point
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // Calculate span with padding (20% extra on each side)
        let latDelta = (maxLat - minLat) * 1.4
        let lonDelta = (maxLon - minLon) * 1.4
        
        // Ensure minimum zoom level for very close points
        let minDelta = 0.005
        let finalLatDelta = max(latDelta, minDelta)
        let finalLonDelta = max(lonDelta, minDelta)
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: finalLatDelta, longitudeDelta: finalLonDelta)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 { // Less than 1 day
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 604800 { // Less than 1 week
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else if timeInterval < 2592000 { // Less than 1 month (30 days)
            let weeks = Int(timeInterval / 604800)
            return "\(weeks)w"
        } else {
            let months = Int(timeInterval / 2592000)
            return "\(months)mo"
        }
    }
}

// MARK: - Current Location Map View
struct CurrentLocationMapView: View {
    @ObservedObject var locationManager: LocationManager
    var parkingLocation: CLLocation? = nil
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var isHeadingMode: Bool = false
    @State private var showFullscreenMap = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Position")
                    .font(.headline)
                Spacer()
                if locationManager.location != nil {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Live")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Button(action: {
                    isHeadingMode.toggle()
                    if isHeadingMode {
                        locationManager.startUpdatingHeading()
                    } else {
                        locationManager.stopUpdatingHeading()
                        // Snap back to north-up
                        if let location = locationManager.location {
                            let region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            )
                            withAnimation(.easeInOut(duration: 0.3)) {
                                mapCameraPosition = .region(region)
                            }
                        }
                    }
                }) {
                    Image(systemName: isHeadingMode ? "location.north.fill" : "location.north.line.fill")
                        .foregroundColor(isHeadingMode ? .blue : .secondary)
                }
            }
            
            if let location = locationManager.location {
                Map(position: $mapCameraPosition) {
                    Annotation("Current Location", coordinate: location.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 20, height: 20)
                        }
                        .shadow(radius: 3)
                    }
                    if let parking = parkingLocation {
                        Annotation("Parking", coordinate: parking.coordinate) {
                            Image(systemName: "car.fill")
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Circle().fill(.white))
                                .shadow(radius: 2)
                        }
                    }
                }
                .frame(height: 200)
                .cornerRadius(10)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                }
                .onTapGesture { showFullscreenMap = true }
                .fullScreenCover(isPresented: $showFullscreenMap) {
                    FullscreenCurrentLocationMapView(
                        locationManager: locationManager,
                        parkingLocation: parkingLocation
                    )
                }
                .onAppear {
                    updateMapPosition(for: location)
                }
                .onChange(of: locationManager.location) { _, newLocation in
                    if let newLocation = newLocation {
                        updateMapPosition(for: newLocation)
                    }
                }
                .onChange(of: locationManager.heading) { _, newHeading in
                    if isHeadingMode, let location = locationManager.location {
                        updateCameraForHeading(location: location, heading: newHeading)
                    }
                }
                .onDisappear {
                    locationManager.stopUpdatingHeading()
                    isHeadingMode = false
                }
                
                if isHeadingMode {
                    CompassRoseView(heading: locationManager.heading)
                }
                
                // Coordinates display
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lat: \(String(format: "%.6f", location.coordinate.latitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Lon: \(String(format: "%.6f", location.coordinate.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Alt: \(String(format: "%.1f", location.altitude)) m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Acc: ±\(String(format: "%.1f", location.horizontalAccuracy)) m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No location available")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Ensure location services are enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func updateMapPosition(for location: CLLocation) {
        if isHeadingMode {
            updateCameraForHeading(location: location, heading: locationManager.heading)
        } else {
            let newRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            withAnimation(.easeInOut(duration: 0.5)) {
                mapCameraPosition = .region(newRegion)
            }
        }
    }
    
    private func updateCameraForHeading(location: CLLocation, heading: CLLocationDirection) {
        let camera = MapCamera(
            centerCoordinate: location.coordinate,
            distance: 600,
            heading: heading,
            pitch: 0
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            mapCameraPosition = .camera(camera)
        }
    }
}

// MARK: - Trip Analysis Section View
struct TripAnalysisSectionView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedTimeRange: TimeRange
    @State private var tripStats: TripStats = .empty
    @State private var elevationPoints: [ElevationPoint] = []
    @State private var speedPoints: [SpeedPoint] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip Analysis")
                .font(.headline)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else if tripStats.pointCount == 0 {
                Text("No data for selected range")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                TripStatsSummaryView(stats: tripStats)
                
                if elevationPoints.count >= 2 {
                    TripElevationChartView(points: elevationPoints)
                }
                
                if speedPoints.count >= 2 {
                    TripSpeedChartView(points: speedPoints)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .onAppear {
            loadAndAnalyze()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            loadAndAnalyze()
        }
        .onChange(of: locationManager.lastLocationSaved) { _, _ in
            if locationManager.isRecording {
                loadAndAnalyze()
            }
        }
    }
    
    private func loadAndAnalyze() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                let records: [LocationRecord]
                switch selectedTimeRange {
                case .lastMonth:
                    records = try await locationManager.dataManager.fetchLocationRecords(since: Calendar.current.date(byAdding: .day, value: -30, to: Date())!)
                case .last24Hours:
                    records = try await locationManager.dataManager.fetchLocationRecordsLast24Hours()
                case .lastWeek:
                    records = try await locationManager.dataManager.fetchLocationRecordsLastWeek()
                }
                let stats = computeTripStats(from: records)
                let (elevPts, spdPts) = buildChartData(from: records)
                await MainActor.run {
                    self.tripStats = stats
                    self.elevationPoints = elevPts
                    self.speedPoints = spdPts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Trip Stats Summary View
struct TripStatsSummaryView: View {
    let stats: TripStats
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            TripStatCell(title: "Distance", value: formatDistance(stats.totalDistanceMeters), icon: "arrow.triangle.swap")
            TripStatCell(title: "Duration", value: formatDuration(stats.durationSeconds), icon: "clock")
            TripStatCell(title: "Avg Speed", value: formatSpeed(stats.averageSpeedMps), icon: "speedometer")
            TripStatCell(title: "Elev Gain", value: String(format: "+%.0f m", stats.elevationGainMeters), icon: "arrow.up.right")
            TripStatCell(title: "Elev Loss", value: String(format: "-%.0f m", stats.elevationLossMeters), icon: "arrow.down.right")
            TripStatCell(title: "Points", value: "\(stats.pointCount)", icon: "mappin.circle")
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private func formatSpeed(_ mps: Double) -> String {
        let kph = mps * 3.6
        return String(format: "%.1f km/h", kph)
    }
}

struct TripStatCell: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Trip Elevation Chart View
struct TripElevationChartView: View {
    let points: [ElevationPoint]
    
    private var altitudeRange: ClosedRange<Double> {
        let altitudes = points.map { $0.altitudeMeters }
        let minAlt = (altitudes.min() ?? 0) - 10
        let maxAlt = (altitudes.max() ?? 100) + 10
        return minAlt...maxAlt
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Elevation Profile")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Chart(points) { point in
                AreaMark(
                    x: .value("Distance (km)", point.cumulativeDistanceKm),
                    y: .value("Altitude (m)", point.altitudeMeters)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.4), .blue.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                LineMark(
                    x: .value("Distance (km)", point.cumulativeDistanceKm),
                    y: .value("Altitude (m)", point.altitudeMeters)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYScale(domain: altitudeRange)
            .chartXAxisLabel("Distance (km)")
            .chartYAxisLabel("Altitude (m)")
            .frame(height: 120)
        }
    }
}

// MARK: - Trip Speed Chart View
struct TripSpeedChartView: View {
    let points: [SpeedPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Speed Profile")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Chart(points) { point in
                BarMark(
                    x: .value("Distance (km)", point.cumulativeDistanceKm),
                    y: .value("Speed (km/h)", point.speedKph)
                )
                .foregroundStyle(Color.green.gradient)
            }
            .chartXAxisLabel("Distance (km)")
            .chartYAxisLabel("Speed (km/h)")
            .frame(height: 100)
        }
    }
}

// MARK: - Compass Rose View
struct CompassRoseView: View {
    let heading: CLLocationDirection
    
    private var cardinal: String {
        switch heading {
        case 337.5...360, 0..<22.5: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default: return "N"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .frame(width: 44, height: 44)
                
                Text("N")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
                    .rotationEffect(.degrees(-heading))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f°", heading))
                    .font(.system(.caption, design: .monospaced))
                Text(cardinal)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Parking Section View

struct ParkingSectionView: View {
    @ObservedObject var parkingManager: ParkingManager
    @ObservedObject var locationManager: LocationManager
    @State private var parkingAddress: String?
    @State private var isGeocodingParking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                Text("Parking")
                    .font(.headline)
                Spacer()
            }

            if parkingManager.parkingLocation != nil {
                if let current = locationManager.location,
                   let (distance, bearing) = parkingManager.distanceAndBearing(from: current) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distance")
                                .font(.caption).foregroundColor(.secondary)
                            Text(distance < 1000
                                 ? String(format: "%.0f m", distance)
                                 : String(format: "%.2f km", distance / 1000))
                                .font(.title2).bold()
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Direction")
                                .font(.caption).foregroundColor(.secondary)
                            Text(parkingManager.cardinalDirection(from: bearing))
                                .font(.title2).bold()
                        }
                        Spacer()
                        if let date = parkingManager.parkingDate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Parked")
                                    .font(.caption).foregroundColor(.secondary)
                                Text(date, style: .relative)
                                    .font(.callout)
                            }
                        }
                    }
                }

                HStack {
                    Text("Parked at")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if isGeocodingParking {
                        ProgressView().scaleEffect(0.7)
                    } else if let address = parkingAddress {
                        Text(address)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = address
                                } label: {
                                    Label("Copy Address", systemImage: "doc.on.doc")
                                }
                            }
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(role: .destructive) {
                    parkingManager.clearParking()
                } label: {
                    Label("Clear Parking", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    if let loc = locationManager.location {
                        parkingManager.saveParking(location: loc)
                    }
                } label: {
                    Label("Save Parking", systemImage: "pin.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(locationManager.location == nil)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .onChange(of: parkingManager.parkingLocation) { _, newParking in
            geocodeParkingLocation(newParking)
        }
        .onAppear {
            geocodeParkingLocation(parkingManager.parkingLocation)
        }
    }

    private func geocodeParkingLocation(_ location: CLLocation?) {
        guard let location else {
            parkingAddress = nil
            return
        }
        isGeocodingParking = true
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            DispatchQueue.main.async {
                isGeocodingParking = false
                if let p = placemarks?.first {
                    var parts: [String] = []
                    if let number = p.subThoroughfare { parts.append(number) }
                    if let street = p.thoroughfare {
                        parts.append(street)
                    } else if let subLocality = p.subLocality {
                        parts.append(subLocality)
                    } else if let area = p.administrativeArea {
                        parts.append(area)
                    }
                    if let city = p.locality { parts.append(city) }
                    parkingAddress = parts.isEmpty ? p.country : parts.joined(separator: ", ")
                }
            }
        }
    }
}

// MARK: - Weather Section View

struct WeatherSectionView: View {
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .symbolRenderingMode(.hierarchical)
                Text("Weather")
                    .font(.headline)
                Spacer()
                if weatherManager.isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }

            if let error = weatherManager.errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }

            if let current = weatherManager.current {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: WeatherManager.sfSymbol(for: current.weatherCode))
                            .font(.system(size: 32))
                            .symbolRenderingMode(.hierarchical)
                        Text(WeatherManager.description(for: current.weatherCode))
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 80)

                    Text(String(format: "%.1f°C", current.temperature))
                        .font(.title).bold()

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Label(String(format: "%.0f km/h", current.windSpeed),
                              systemImage: "wind")
                            .font(.caption)
                        Label("\(current.humidity)%", systemImage: "humidity.fill")
                            .font(.caption)
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                if !weatherManager.hourlyForecast.isEmpty {
                    Divider()
                    Text("Next 24 Hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(weatherManager.hourlyForecast) { hour in
                                VStack(spacing: 4) {
                                    Text(hour.time, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Image(systemName: WeatherManager.sfSymbol(for: hour.weatherCode))
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.body)
                                    Text(String(format: "%.0f°", hour.temperature))
                                        .font(.caption).bold()
                                }
                                .frame(width: 44)
                            }
                        }
                    }
                }
            } else if !weatherManager.isLoading {
                Text("Weather data unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

// MARK: - Trip Save Sheet

struct TripSaveSheet: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var tripName: String
    let selectedTimeRange: TimeRange
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Name") {
                    TextField("e.g. Morning Run", text: $tripName)
                }
                Section {
                    Text("Recording started: \(locationManager.recordingStartDate.map { $0.formatted(.dateTime.month().day().hour().minute()) } ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Save Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        locationManager.clearRecordingState()
                        tripName = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveTrip()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveTrip() {
        isSaving = true
        let startDate = locationManager.recordingStartDate ?? Date().addingTimeInterval(-60)
        let endDate = Date()
        let name = tripName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Trip \(endDate.formatted(.dateTime.month().day().hour().minute()))"
            : tripName

        Task {
            do {
                let records = try await locationManager.dataManager.fetchLocationRecords(
                    from: startDate, to: endDate)
                let stats = computeTripStats(from: records)
                let trip = TripRecord(
                    name: name,
                    startDate: startDate,
                    endDate: endDate,
                    totalDistance: stats.totalDistanceMeters,
                    elevationGain: stats.elevationGainMeters,
                    elevationLoss: stats.elevationLossMeters,
                    duration: stats.durationSeconds,
                    avgSpeed: stats.averageSpeedMps,
                    pointCount: stats.pointCount
                )
                try await locationManager.dataManager.saveTripRecord(trip)
            } catch {
                LogManager.warning("Error saving trip: \(error.localizedDescription)", category: "Trip")
            }
            await MainActor.run {
                locationManager.clearRecordingState()
                tripName = ""
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Trip History View

struct TripHistoryView: View {
    let dataManager: CacheAwareDataManager
    @State private var trips: [TripRecord] = []
    @State private var isLoading = true
    @State private var selectedTrip: TripRecord?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading trips...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips",
                        systemImage: "map",
                        description: Text("Stop a recording session to save a trip")
                    )
                } else {
                    List(trips) { trip in
                        Button {
                            selectedTrip = trip
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                HStack {
                                    Text(trip.startDate, style: .date)
                                    Spacer()
                                    Text(trip.totalDistance >= 1000
                                         ? String(format: "%.1f km", trip.totalDistance / 1000)
                                         : String(format: "%.0f m", trip.totalDistance))
                                    Text("·")
                                    Text(formatDurationShort(trip.duration))
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trip History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(trip: trip, dataManager: dataManager)
            }
            .task {
                do {
                    trips = try await dataManager.fetchTripRecords()
                } catch {
                    LogManager.warning("Error fetching trips: \(error.localizedDescription)", category: "Trip")
                }
                isLoading = false
            }
        }
    }

    private func formatDurationShort(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Trip Detail View

struct TripDetailView: View {
    let trip: TripRecord
    let dataManager: CacheAwareDataManager
    @State private var records: [LocationRecord] = []
    @State private var isLoading = true
    @State private var elevationPoints: [ElevationPoint] = []
    @State private var speedPoints: [SpeedPoint] = []
    @State private var showFullscreenMap = false
    @Environment(\.dismiss) private var dismiss

    private var stats: TripStats {
        TripStats(
            totalDistanceMeters: trip.totalDistance,
            elevationGainMeters: trip.elevationGain,
            elevationLossMeters: trip.elevationLoss,
            durationSeconds: trip.duration,
            averageSpeedMps: trip.avgSpeed,
            pointCount: trip.pointCount
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TripStatsSummaryView(stats: stats)
                        .padding(.horizontal)

                    if isLoading {
                        ProgressView("Loading route...")
                            .frame(height: 200)
                    } else if !records.isEmpty {
                        Map {
                            MapPolyline(coordinates: records.map {
                                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                            })
                            .stroke(.blue, lineWidth: 3)

                            if let first = records.first {
                                Annotation("Start", coordinate: CLLocationCoordinate2D(
                                    latitude: first.latitude, longitude: first.longitude)) {
                                    Image(systemName: "flag.fill").foregroundColor(.green)
                                }
                            }
                            if let last = records.last {
                                Annotation("End", coordinate: CLLocationCoordinate2D(
                                    latitude: last.latitude, longitude: last.longitude)) {
                                    Image(systemName: "flag.checkered").foregroundColor(.red)
                                }
                            }
                        }
                        .frame(height: 250)
                        .cornerRadius(10)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(8)
                        }
                        .onTapGesture { showFullscreenMap = true }
                        .fullScreenCover(isPresented: $showFullscreenMap) {
                            FullscreenTripMapView(records: records)
                        }
                        .padding(.horizontal)

                        if elevationPoints.count >= 2 {
                            TripElevationChartView(points: elevationPoints)
                                .padding(.horizontal)
                        }
                        if speedPoints.count >= 2 {
                            TripSpeedChartView(points: speedPoints)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    let fetched = try await dataManager.fetchLocationRecords(
                        from: trip.startDate, to: trip.endDate)
                    let (elev, spd) = buildChartData(from: fetched)
                    await MainActor.run {
                        records = fetched
                        elevationPoints = elev
                        speedPoints = spd
                    }
                } catch {
                    LogManager.warning("Error loading trip route: \(error.localizedDescription)", category: "Trip")
                }
                isLoading = false
            }
        }
    }
}


// MARK: - Fullscreen Map Views

struct FullscreenCurrentLocationMapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager: LocationManager
    var parkingLocation: CLLocation?
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $mapCameraPosition) {
                if let location = locationManager.location {
                    Annotation("Current Location", coordinate: location.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 24, height: 24)
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 24, height: 24)
                        }
                        .shadow(radius: 3)
                    }
                }
                if let parking = parkingLocation {
                    Annotation("Parking", coordinate: parking.coordinate) {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Circle().fill(.white))
                            .shadow(radius: 2)
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                if let loc = locationManager.location {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))
                }
            }
            .onChange(of: locationManager.location) { _, newLocation in
                if let newLocation = newLocation {
                    withAnimation {
                        mapCameraPosition = .region(MKCoordinateRegion(
                            center: newLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))
                    }
                }
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 80 { dismiss() }
        })
    }
}

struct FullscreenLocationMapView: View {
    @Environment(\.dismiss) private var dismiss
    let locationRecords: [LocationRecord]
    let showHeatmap: Bool
    let heatmapCells: [HeatmapCell]
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var displayCoordinates: [CLLocationCoordinate2D] = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $mapCameraPosition) {
                if displayCoordinates.count > 1 {
                    MapPolyline(coordinates: displayCoordinates)
                        .stroke(.blue, lineWidth: 2)
                }
                if let oldest = locationRecords.last {
                    Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: oldest.latitude, longitude: oldest.longitude)) {
                        Image(systemName: "flag.circle.fill")
                            .foregroundColor(.green)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
                if let newest = locationRecords.first {
                    Annotation("Latest", coordinate: CLLocationCoordinate2D(latitude: newest.latitude, longitude: newest.longitude)) {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
                if showHeatmap {
                    ForEach(heatmapCells) { cell in
                        MapCircle(center: cell.coordinate, radius: 80)
                            .foregroundStyle(
                                HeatmapManager.color(for: cell.normalizedIntensity)
                                    .opacity(0.3 + 0.4 * cell.normalizedIntensity)
                            )
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                displayCoordinates = decimateCoordinates(locationRecords, minDistance: 15)
                if !locationRecords.isEmpty {
                    let lats = locationRecords.map { $0.latitude }
                    let lons = locationRecords.map { $0.longitude }
                    let minLat = lats.min()!, maxLat = lats.max()!
                    let minLon = lons.min()!, maxLon = lons.max()!
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                        span: MKCoordinateSpan(
                            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
                            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
                        )
                    ))
                }
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 80 { dismiss() }
        })
    }
}

struct FullscreenTripMapView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [LocationRecord]
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $mapCameraPosition) {
                MapPolyline(coordinates: records.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(.blue, lineWidth: 3)

                if let first = records.first {
                    Annotation("Start", coordinate: CLLocationCoordinate2D(
                        latitude: first.latitude, longitude: first.longitude)) {
                        Image(systemName: "flag.fill").foregroundColor(.green)
                    }
                }
                if let last = records.last {
                    Annotation("End", coordinate: CLLocationCoordinate2D(
                        latitude: last.latitude, longitude: last.longitude)) {
                        Image(systemName: "flag.checkered").foregroundColor(.red)
                    }
                }
            }
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 80 { dismiss() }
        })
    }
}

#Preview {
    ContentView()
}
