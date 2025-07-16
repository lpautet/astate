import Foundation
import CoreMotion

class BarometerManager: ObservableObject {
    private let altimeter = CMAltimeter()
    
    @Published var pressure: Double = 0.0
    @Published var relativeAltitude: Double = 0.0
    @Published var isAvailable: Bool = false
    
    init() {
        isAvailable = CMAltimeter.isRelativeAltitudeAvailable()
        
        if isAvailable {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                
                // Pressure is in kilopascals (kPa)
                self?.pressure = data.pressure.doubleValue
                
                // Relative altitude is in meters
                self?.relativeAltitude = data.relativeAltitude.doubleValue
            }
        }
    }
    
    deinit {
        if isAvailable {
            altimeter.stopRelativeAltitudeUpdates()
        }
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