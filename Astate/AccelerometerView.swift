import SwiftUI

struct AccelerometerView: View {
    let axis1: Double
    let axis2: Double
    let title: String
    
    // Constants for visualization
    private let maxAcceleration: Double = 1.0 // Maximum acceleration to show (1G)
    private let circleSize: CGFloat = 100 // Made smaller to fit 3 in a row
    private let crossSize: CGFloat = 15
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: circleSize, height: circleSize)
                
                // Center cross
                Cross()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: crossSize, height: crossSize)
                
                // Moving cross based on accelerometer values
                Cross()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: crossSize, height: crossSize)
                    .offset(x: CGFloat(axis1) * (circleSize/2), y: CGFloat(axis2) * (circleSize/2))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: axis1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: axis2)
            }
            .frame(width: circleSize, height: circleSize)
        }
    }
}

struct AccelerometerRow: View {
    let x: Double
    let y: Double
    let z: Double
    
    var body: some View {
        HStack(spacing: 20) {
            AccelerometerView(axis1: x, axis2: y, title: "X-Y")
            AccelerometerView(axis1: x, axis2: z, title: "X-Z")
            AccelerometerView(axis1: y, axis2: z, title: "Y-Z")
        }
    }
}

struct Cross: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Horizontal line
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        
        // Vertical line
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        
        return path
    }
}

#Preview {
    AccelerometerRow(x: 0.5, y: -0.3, z: 0.1)
} 