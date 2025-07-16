import Foundation
import CoreMotion

class MagnetometerManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    @Published var heading: Double = 0.0
    @Published var isAvailable: Bool = false
    
    init() {
        isAvailable = motionManager.isMagnetometerAvailable
        
        if isAvailable {
            motionManager.magnetometerUpdateInterval = 0.1
            motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                
                self?.x = data.magneticField.x
                self?.y = data.magneticField.y
                self?.z = data.magneticField.z
                
                // Calculate heading (in degrees)
                let heading = atan2(data.magneticField.y, data.magneticField.x) * 180 / .pi
                self?.heading = (heading + 360).truncatingRemainder(dividingBy: 360)
            }
        }
    }
    
    deinit {
        if isAvailable {
            motionManager.stopMagnetometerUpdates()
        }
    }
    
    // Get cardinal direction from heading
    var cardinalDirection: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((heading + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)
        return directions[index]
    }
    
    // Get total magnetic field strength in microtesla
    var totalFieldStrength: Double {
        return sqrt(x * x + y * y + z * z)
    }
} 