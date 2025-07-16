import Foundation
import CoreMotion

class AccelerometerManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    @Published var z: Double = 0.0
    @Published var isAvailable: Bool = false
    
    init() {
        isAvailable = motionManager.isAccelerometerAvailable
        
        if isAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
        }
    }
    
    func startUpdates() {
        guard motionManager.isAccelerometerAvailable else { 
            return 
        }
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            
            DispatchQueue.main.async {
                self?.x = data.acceleration.x
                self?.y = data.acceleration.y
                self?.z = data.acceleration.z
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopAccelerometerUpdates()
    }
    
    deinit {
        stopUpdates()
    }
} 