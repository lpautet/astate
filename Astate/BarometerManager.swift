import Foundation
import CoreMotion

class BarometerManager: ObservableObject {
    private let altimeter = CMAltimeter()
    
    @Published var pressure: Double = 0.0
    @Published var relativeAltitude: Double = 0.0
    @Published var isAvailable: Bool = false
    
    init() {
        isAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    }
    
    func startUpdates() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            return
        }
        
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            
            DispatchQueue.main.async {
                // Pressure is in kilopascals (kPa)
                self?.pressure = data.pressure.doubleValue
                
                // Relative altitude is in meters
                self?.relativeAltitude = data.relativeAltitude.doubleValue
            }
        }
    }
    
    func stopUpdates() {
        altimeter.stopRelativeAltitudeUpdates()
    }
    
    deinit {
        stopUpdates()
    }
    
    // Convert pressure from kPa to different units
    var pressureInHectopascals: Double {
        return pressure * 10 // 1 kPa = 10 hPa
    }
    
    var pressureInMillibars: Double {
        return pressure * 10 // 1 kPa = 10 mbar
    }
    
    var pressureInInchesOfMercury: Double {
        return pressure * 2.953 // 1 kPa ≈ 2.953 inHg
    }
} 
