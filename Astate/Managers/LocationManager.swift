import Foundation
import CoreLocation
import SwiftUI
import UserNotifications

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let cloudKitManager = CloudKitManager()
    private var recordingTimer: Timer?
    private var notificationTimer: Timer?
    private var lastNotificationTime: Date?
    private var pendingExtremes: [String] = []
    
    @Published var location: CLLocation?
    @Published var speed: Double = 0.0
    @Published var speedAccuracy: Double = 0.0
    @Published var minAltitude: Double = Double.infinity
    @Published var maxAltitude: Double = -Double.infinity
    @Published var minLatitude: Double = Double.infinity
    @Published var maxLatitude: Double = -Double.infinity
    @Published var minLongitude: Double = Double.infinity
    @Published var maxLongitude: Double = -Double.infinity
    @Published var isRecording = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocationSaved = Date() // Trigger for map updates
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        
        requestNotificationPermission()
        
        // Request location permission when initializing
        requestLocationPermission()
        
        // Load existing min/max values from CloudKit
        loadMinMaxValues()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    private func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied:
            break
        case .restricted:
            break
        case .authorizedWhenInUse:
            // If we already have when-in-use, try to get always authorization for background recording
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    private func loadMinMaxValues() {
        Task {
            do {
                if let minMaxRecord = try await cloudKitManager.fetchMinMaxRecord() {
                    DispatchQueue.main.async {
                        self.minAltitude = minMaxRecord.minAltitude
                        self.maxAltitude = minMaxRecord.maxAltitude
                        self.minLatitude = minMaxRecord.minLatitude
                        self.maxLatitude = minMaxRecord.maxLatitude
                        self.minLongitude = minMaxRecord.minLongitude
                        self.maxLongitude = minMaxRecord.maxLongitude
                    }
                }
            } catch {
                print("Error loading min/max values: \(error.localizedDescription)")
                // Keep default values if loading fails
            }
        }
    }
    
    private func saveMinMaxValues() {
        let minMaxRecord = MinMaxRecord(
            minAltitude: minAltitude,
            maxAltitude: maxAltitude,
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude
        )
        
        Task {
            do {
                try await cloudKitManager.saveMinMaxRecord(minMaxRecord)
            } catch {
                print("Error saving min/max values: \(error.localizedDescription)")
            }
        }
    }
    
    func startUpdatingLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        // Only set background properties if we have always authorization
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.showsBackgroundLocationIndicator = true
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func startRecording() {
        isRecording = true
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.recordCurrentLocation()
        }
    }
    
    func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    deinit {
        recordingTimer?.invalidate()
        notificationTimer?.invalidate()
    }
    
    private func recordCurrentLocation() {
        guard let location = location else { return }
        
        let record = LocationRecord(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude
        )
        
        Task {
            do {
                try await cloudKitManager.saveLocationRecord(record)
                updateMinMaxValues(with: location)
                
                // Notify that new location data was saved
                DispatchQueue.main.async {
                    self.lastLocationSaved = Date()
                }
            } catch {
                print("Error saving location record: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateMinMaxValues(with location: CLLocation) {
        let altitude = location.altitude
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        var hasNewExtreme = false
        
        // Update min/max values
        if altitude < minAltitude {
            minAltitude = altitude
            notifyThresholdReached(type: "altitude", value: altitude, isMin: true)
            hasNewExtreme = true
        }
        if altitude > maxAltitude {
            maxAltitude = altitude
            notifyThresholdReached(type: "altitude", value: altitude, isMin: false)
            hasNewExtreme = true
        }
        
        if latitude < minLatitude {
            minLatitude = latitude
            notifyThresholdReached(type: "latitude", value: latitude, isMin: true)
            hasNewExtreme = true
        }
        if latitude > maxLatitude {
            maxLatitude = latitude
            notifyThresholdReached(type: "latitude", value: latitude, isMin: false)
            hasNewExtreme = true
        }
        
        if longitude < minLongitude {
            minLongitude = longitude
            notifyThresholdReached(type: "longitude", value: longitude, isMin: true)
            hasNewExtreme = true
        }
        if longitude > maxLongitude {
            maxLongitude = longitude
            notifyThresholdReached(type: "longitude", value: longitude, isMin: false)
            hasNewExtreme = true
        }
        
        // Save to CloudKit only if we found a new extreme
        if hasNewExtreme {
            saveMinMaxValues()
        }
    }
    
    private func notifyThresholdReached(type: String, value: Double, isMin: Bool) {
        let extremeDescription = String(format: "\(isMin ? "Min" : "Max") \(type.capitalized): %.6f", value)
        
        // Add to pending extremes
        pendingExtremes.append(extremeDescription)
        
        let now = Date()
        let oneHour: TimeInterval = 3600 // 1 hour in seconds
        
        // Check if we can send notification immediately (first time or > 1 hour since last)
        if let lastTime = lastNotificationTime, now.timeIntervalSince(lastTime) < oneHour {
            // Still within 1-hour window, schedule delayed notification if not already scheduled
            if notificationTimer == nil {
                let timeUntilNextNotification = oneHour - now.timeIntervalSince(lastTime)
                scheduleDelayedNotification(after: timeUntilNextNotification)
            }
        } else {
            // Can send immediately (first notification or > 1 hour passed)
            sendCombinedNotification()
        }
    }
    
    private func scheduleDelayedNotification(after delay: TimeInterval) {
        notificationTimer?.invalidate()
        notificationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.sendCombinedNotification()
        }
    }
    
    private func sendCombinedNotification() {
        guard !pendingExtremes.isEmpty else { return }
        
        let content = UNMutableNotificationContent()
        
        if pendingExtremes.count == 1 {
            content.title = "New Extreme Found"
            content.body = pendingExtremes.first!
        } else {
            content.title = "New Extremes Found"
            content.body = pendingExtremes.joined(separator: ", ")
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
        
        // Reset for next cycle
        lastNotificationTime = Date()
        pendingExtremes.removeAll()
        notificationTimer?.invalidate()
        notificationTimer = nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
            self.speed = location.speed >= 0 ? location.speed : 0
            self.speedAccuracy = location.speedAccuracy >= 0 ? location.speedAccuracy : 0
            
            if self.isRecording {
                self.updateMinMaxValues(with: location)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors silently
    }
} 