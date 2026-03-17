import Foundation
import CoreLocation
import SwiftUI

struct HeatmapCell: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let normalizedIntensity: Double // 0.0 to 1.0
}

class HeatmapManager: ObservableObject {
    @Published var cells: [HeatmapCell] = []

    func buildHeatmap(from records: [LocationRecord]) {
        guard !records.isEmpty else {
            cells = []
            return
        }

        var resolution = 0.001 // ~111 meters per cell

        // Quick scan to see if we'd get too many cells; double resolution if so
        let quickKeys = Set(records.map {
            "\(Int($0.latitude / resolution)),\(Int($0.longitude / resolution))"
        })
        if quickKeys.count > 500 {
            resolution = 0.002
        }

        var grid: [String: (lat: Double, lon: Double, count: Int)] = [:]

        for record in records {
            let gridLat = (record.latitude / resolution).rounded(.down) * resolution + resolution / 2
            let gridLon = (record.longitude / resolution).rounded(.down) * resolution + resolution / 2
            let key = "\(Int(record.latitude / resolution)),\(Int(record.longitude / resolution))"
            if let existing = grid[key] {
                grid[key] = (existing.lat, existing.lon, existing.count + 1)
            } else {
                grid[key] = (gridLat, gridLon, 1)
            }
        }

        let maxCount = grid.values.map(\.count).max() ?? 1

        cells = grid.values.map { cell in
            HeatmapCell(
                coordinate: CLLocationCoordinate2D(latitude: cell.lat, longitude: cell.lon),
                count: cell.count,
                normalizedIntensity: Double(cell.count) / Double(maxCount)
            )
        }
    }

    static func color(for intensity: Double) -> Color {
        if intensity < 0.5 {
            let t = intensity / 0.5
            return Color(red: t, green: 0.8, blue: 0)
        } else {
            let t = (intensity - 0.5) / 0.5
            return Color(red: 0.8 + 0.2 * t, green: 0.8 * (1 - t), blue: 0)
        }
    }
}
