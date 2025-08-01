import Foundation
import CoreLocation
import SwiftUI
import UserNotifications

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    let cloudKitManager = CloudKitManager()
    private var recordingTimer: Timer?
    private var lastRecordingTime: Date?
    private var lastRecordedLocation: CLLocation?
    private var notificationTimer: Timer?
    private var lastNotificationTime: Date?
    private var pendingExtremes: [String] = []
    private var hasLoadedMinMaxValues = false
    
    @Published var location: CLLocation?
    @Published var speed: Double = 0.0
    @Published var speedAccuracy: Double = 0.0
    @Published var minAltitude: Double = Double.infinity
    @Published var maxAltitude: Double = -Double.infinity
    @Published var minLatitude: Double = Double.infinity
    @Published var maxLatitude: Double = -Double.infinity
    @Published var minLongitude: Double = Double.infinity
    @Published var maxLongitude: Double = -Double.infinity
    @Published var minSpeed: Double = Double.infinity
    @Published var maxSpeed: Double = -Double.infinity
    @Published var isRecording = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocationSaved = Date() // Trigger for map updates
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0  // Default: 10 meters - better for battery while still responsive
        
        // Request notification permission (this is safe during init)
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                LogManager.info("Notification permission granted", category: "System")
            } else if let error = error {
                LogManager.warning("Error requesting notification permission: \(error.localizedDescription)", category: "System")
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
    
    private func loadMinMaxValuesIfNeeded() {
        guard !hasLoadedMinMaxValues else { return }
        hasLoadedMinMaxValues = true
        
        Task { @MainActor [weak self] in
            do {
                guard let self = self else { return }
                if let minMaxRecord = try await self.cloudKitManager.fetchMinMaxRecord() {
                    self.minAltitude = minMaxRecord.minAltitude
                    self.maxAltitude = minMaxRecord.maxAltitude
                    self.minLatitude = minMaxRecord.minLatitude
                    self.maxLatitude = minMaxRecord.maxLatitude
                    self.minLongitude = minMaxRecord.minLongitude
                    self.maxLongitude = minMaxRecord.maxLongitude
                    self.minSpeed = minMaxRecord.minSpeed
                    self.maxSpeed = minMaxRecord.maxSpeed
                }
            } catch {
                LogManager.warning("Error loading min/max values: \(error.localizedDescription)", category: "Location")
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
            maxLongitude: maxLongitude,
            minSpeed: minSpeed,
            maxSpeed: maxSpeed
        )
        
        Task {
            do {
                try await cloudKitManager.saveMinMaxRecord(minMaxRecord)
            } catch {
                LogManager.warning("Error saving min/max values: \(error.localizedDescription)", category: "Location")
            }
        }
    }
    
    func startUpdatingLocation() {
        // Defer authorization status update to avoid state modification during view updates
        Task { @MainActor in
            self.authorizationStatus = self.locationManager.authorizationStatus
        }
        
        // Load min/max values when we first start location updates
        loadMinMaxValuesIfNeeded()
        
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
    
    func setHighPrecisionMode(_ enabled: Bool) {
        let newFilter: CLLocationDistance = enabled ? 1.0 : 10.0
        if locationManager.distanceFilter != newFilter {
            locationManager.distanceFilter = newFilter
            LogManager.info("Distance filter changed to \(newFilter)m (high precision: \(enabled))", category: "Location")
        }
    }
    
    func startRecording() {
        isRecording = true
        LogManager.info("Started location recording", category: "Location")
        // Record immediately when starting
        recordCurrentLocation()
        lastRecordingTime = Date()
        
        // Timer for foreground recording (will be suspended in background)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.recordCurrentLocation()
        }
    }
    
    func stopRecording() {
        isRecording = false
        LogManager.info("Stopped location recording", category: "Location")
        recordingTimer?.invalidate()
        recordingTimer = nil
        lastRecordingTime = nil
        lastRecordedLocation = nil
    }
    
    deinit {
        recordingTimer?.invalidate()
        notificationTimer?.invalidate()
    }
    
    private func recordCurrentLocation() {
        guard let location = location else { return }
        
        // Check if we should record this location (distance-based filtering)
        let shouldRecord: Bool
        if let lastLocation = lastRecordedLocation {
            // Only record if moved at least 5 meters from last recorded position
            let distance = location.distance(from: lastLocation)
            shouldRecord = distance >= 5.0
        } else {
            // Always record the first location
            shouldRecord = true
        }
        
        // Update last recording time regardless (to maintain 60-second intervals)
        lastRecordingTime = Date()
        
        // Only save to CloudKit if position has changed meaningfully
        if shouldRecord {
            let record = LocationRecord(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude
            )
            
            // Capture distance for logging before updating lastRecordedLocation
            let distanceMoved = lastRecordedLocation?.distance(from: location) ?? 0.0
            
            // Update the last recorded location
            lastRecordedLocation = location
            
            Task { [weak self] in
                do {
                    guard let self = self else { return }
                    try await self.cloudKitManager.saveLocationRecord(record)
                    self.updateMinMaxValues(with: location)
                    
                    // Notify that new location data was saved
                    await MainActor.run {
                        self.lastLocationSaved = Date()
                    }
                    LogManager.info("Location recorded: moved \(String(format: "%.1f", distanceMoved))m", category: "Location")
                } catch {
                    LogManager.critical("Error saving location record: \(error.localizedDescription)", category: "Location")
                }
            }
        } else {
            LogManager.info("Location skipped: only moved \(String(format: "%.1f", location.distance(from: lastRecordedLocation!)))m", category: "Location")
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
        
        // Update speed min/max (only for valid speeds >= 0)
        let currentSpeed = location.speed >= 0 ? location.speed : 0
        if currentSpeed < minSpeed {
            minSpeed = currentSpeed
            notifyThresholdReached(type: "speed", value: currentSpeed, isMin: true)
            hasNewExtreme = true
        }
        if currentSpeed > maxSpeed {
            maxSpeed = currentSpeed
            notifyThresholdReached(type: "speed", value: currentSpeed, isMin: false)
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
                
                // Check if it's time to record (for background recording)
                let now = Date()
                if let lastTime = self.lastRecordingTime {
                    // Record if 60 seconds have passed since last recording
                    if now.timeIntervalSince(lastTime) >= 60.0 {
                        self.recordCurrentLocation()
                    }
                } else {
                    // First recording when starting
                    self.recordCurrentLocation()
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors silently
    }
} 
