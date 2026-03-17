import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct AltitudeEntry: TimelineEntry {
    let date: Date
    let currentAltitude: Double?
    let todayElevationGain: Double?
    let recentPoints: [AltitudeDataPoint]
}

// MARK: - Timeline Provider

struct AltitudeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AltitudeEntry {
        AltitudeEntry(date: Date(), currentAltitude: 350, todayElevationGain: 125, recentPoints: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (AltitudeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AltitudeEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> AltitudeEntry {
        if let data = SharedAltitudeData.load() {
            return AltitudeEntry(
                date: data.lastUpdated,
                currentAltitude: data.currentAltitude,
                todayElevationGain: data.todayElevationGain,
                recentPoints: data.recentPoints
            )
        }
        return AltitudeEntry(date: Date(), currentAltitude: nil, todayElevationGain: nil, recentPoints: [])
    }
}

// MARK: - Sparkline

struct AltitudeSparklineView: View {
    let points: [AltitudeDataPoint]

    var body: some View {
        GeometryReader { geo in
            let altitudes = points.map(\.altitude)
            let minAlt = altitudes.min() ?? 0
            let maxAlt = altitudes.max() ?? 1
            let range = max(maxAlt - minAlt, 1)

            Path { path in
                for (i, point) in points.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(points.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((point.altitude - minAlt) / range))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
}

// MARK: - Small Widget View

struct SmallAltitudeWidgetView: View {
    let entry: AltitudeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "mountain.2.fill")
                    .foregroundColor(.blue)
                Text("Altitude")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let alt = entry.currentAltitude {
                Text(String(format: "%.0f m", alt))
                    .font(.title).bold()
            } else {
                Text("-- m")
                    .font(.title).bold()
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.green)
                    .font(.caption2)
                if let gain = entry.todayElevationGain {
                    Text(String(format: "+%.0f m", gain))
                        .font(.caption).bold()
                } else {
                    Text("-- m").font(.caption)
                }
            }
            Text("Today's gain")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Medium Widget View

struct MediumAltitudeWidgetView: View {
    let entry: AltitudeEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "mountain.2.fill")
                        .foregroundColor(.blue)
                    Text("Altitude")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let alt = entry.currentAltitude {
                    Text(String(format: "%.0f m", alt))
                        .font(.title).bold()
                } else {
                    Text("-- m").font(.title).bold().foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right").foregroundColor(.green).font(.caption2)
                    if let gain = entry.todayElevationGain {
                        Text(String(format: "+%.0f m", gain)).font(.caption).bold()
                    }
                }
                Text("Today's gain").font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            if entry.recentPoints.count > 1 {
                AltitudeSparklineView(points: entry.recentPoints)
                    .frame(width: 120, height: 60)
            }
        }
        .padding()
    }
}

// MARK: - Widget Entry View

struct AstateWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AltitudeEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumAltitudeWidgetView(entry: entry)
        default:
            SmallAltitudeWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct AstateAltitudeWidget: Widget {
    let kind: String = "AstateAltitudeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AltitudeProvider()) { entry in
            if #available(iOS 17.0, *) {
                AstateWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                AstateWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Altitude")
        .description("Current altitude and today's elevation gain.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    AstateAltitudeWidget()
} timeline: {
    AltitudeEntry(date: Date(), currentAltitude: 350, todayElevationGain: 125, recentPoints: [])
}
