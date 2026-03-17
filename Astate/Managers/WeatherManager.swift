import Foundation
import CoreLocation

// MARK: - Weather Models

struct CurrentWeather {
    let temperature: Double
    let weatherCode: Int
    let windSpeed: Double
    let humidity: Int
}

struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let weatherCode: Int
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let relative_humidity_2m: Int
    }
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
    }
    let current: Current
    let hourly: Hourly
}

// MARK: - WeatherManager

class WeatherManager: ObservableObject {
    @Published var current: CurrentWeather?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var lastFetchLocation: CLLocation?
    private var lastFetchTime: Date?

    func fetchIfNeeded(for location: CLLocation) {
        if let lastLoc = lastFetchLocation,
           let lastTime = lastFetchTime,
           location.distance(from: lastLoc) < 1000,
           Date().timeIntervalSince(lastTime) < 900 {
            return
        }
        lastFetchLocation = location
        lastFetchTime = Date()
        Task {
            await fetch(latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude)
        }
    }

    @MainActor
    func fetch(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m&hourly=temperature_2m,weather_code&forecast_hours=24"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            current = CurrentWeather(
                temperature: response.current.temperature_2m,
                weatherCode: response.current.weather_code,
                windSpeed: response.current.wind_speed_10m,
                humidity: response.current.relative_humidity_2m
            )

            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm"
            df.timeZone = TimeZone.current

            hourlyForecast = zip(response.hourly.time,
                                 zip(response.hourly.temperature_2m, response.hourly.weather_code))
                .compactMap { timeStr, tempCode in
                    guard let date = df.date(from: timeStr) else { return nil }
                    return HourlyForecast(time: date, temperature: tempCode.0, weatherCode: tempCode.1)
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - WMO Weather Code Helpers

    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.min.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snowfall"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm + hail"
        default: return "Unknown"
        }
    }
}
