import SwiftUI

struct AccelerometerVisualizationView: View {
    let x: Double
    let y: Double
    let z: Double
    
    var body: HStack<TupleView<(AccelerometerView, AccelerometerView, AccelerometerView)>> {
        HStack(spacing: 20) {
            AccelerometerView(axis1: x, axis2: y, title: "X-Y")
            AccelerometerView(axis1: x, axis2: z, title: "X-Z")
            AccelerometerView(axis1: y, axis2: z, title: "Y-Z")
        }
    }
} 