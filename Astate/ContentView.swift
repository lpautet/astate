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

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var accelerometerManager = AccelerometerManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var barometerManager = BarometerManager()
    @StateObject private var magnetometerManager = MagnetometerManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LocationDataSectionView(manager: locationManager)
                    
                    LocationMapView(locationManager: locationManager)
                    
                    MinMaxValuesSectionView(manager: locationManager)
                    
                    RecordingControlsView(manager: locationManager)
                    
                    AccelerometerValuesSectionView(manager: accelerometerManager)
                    
                    if magnetometerManager.isAvailable {
                        MagnetometerSectionView(manager: magnetometerManager)
                    }
                    
                    if barometerManager.isAvailable {
                        BarometerSectionView(manager: barometerManager)
                    }
                }
                .padding()
            }
            .navigationTitle("Astate")
            .onAppear {
                accelerometerManager.startUpdates()
                locationManager.startUpdatingLocation()
            }
            .onDisappear {
                accelerometerManager.stopUpdates()
                locationManager.stopUpdatingLocation()
            }
        }
    }
}

// MARK: - Location Data Section View
struct LocationDataSectionView: View {
    @ObservedObject var manager: LocationManager
    
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
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
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
                Text("Recording location data every minute")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

// MARK: - Location Map View
struct LocationMapView: View {
    @StateObject private var cloudKitManager = CloudKitManager()
    @ObservedObject var locationManager: LocationManager
    @State private var locationRecords: [LocationRecord] = []
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let error = errorMessage {
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("\(locationRecords.count) points")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                Map(coordinateRegion: $mapRegion, annotationItems: locationRecords) { record in
                    MapPin(coordinate: CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude))
                }
                .frame(height: 250)
                .cornerRadius(10)
            }
            
            HStack {
                if !locationRecords.isEmpty {
                    Text("Latest: \(formatDate(locationRecords.first?.timestamp ?? Date()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Refresh") {
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
        .onChange(of: locationManager.lastLocationSaved) { _ in
            // Auto-refresh map when new location data is saved
            if locationManager.isRecording {
                loadLocationRecords()
            }
        }
    }
    
    private func loadLocationRecords() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let records = try await cloudKitManager.fetchLocationRecords()
                DispatchQueue.main.async {
                    self.locationRecords = records
                    self.isLoading = false
                    self.errorMessage = nil
                    
                    // Update map region to fit all recorded locations
                    if !records.isEmpty {
                        self.mapRegion = self.calculateMapRegion(for: records)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
                print("Error loading location records: \(error.localizedDescription)")
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
}

#Preview {
    ContentView()
}
