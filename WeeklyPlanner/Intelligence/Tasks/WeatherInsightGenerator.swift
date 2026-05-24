import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Single hour of precipitation forecast used by the generator. Value
/// type so test fakes can construct it without WeatherKit.
struct HourlyPrecipitation: Sendable {
    let hourStart: Date
    let precipChance: Double
}

/// Seam over WeatherKit so unit tests don't need the entitlement +
/// network. Production impl wraps `WeatherService.shared`.
@MainActor
protocol WeatherProviding {
    func hourlyPrecipitation(for location: CLLocation, day: Date) async -> [HourlyPrecipitation]
    func currentLocation() async -> CLLocation?
}

/// Emits "Bring an umbrella — rain at <h>pm" when any hour overlapping
/// an event has precipitation chance ≥ threshold. Skips entirely on
/// days with no events.
@MainActor
final class WeatherInsightGenerator: InsightGenerator {
    let kind: InsightKind = .weather

    private let provider: any WeatherProviding
    private let precipThreshold: Double

    init(provider: any WeatherProviding, precipThreshold: Double = 0.4) {
        self.provider = provider
        self.precipThreshold = precipThreshold
    }

    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    func generate(for day: DayContext) async -> AIInsight? {
        guard !day.events.isEmpty else { return nil }
        guard let here = await provider.currentLocation() else { return nil }

        let forecast = await provider.hourlyPrecipitation(for: here, day: day.now)
        guard !forecast.isEmpty else { return nil }

        for hour in forecast {
            guard hour.precipChance >= precipThreshold else { continue }
            let hourEnd = hour.hourStart.addingTimeInterval(3600)
            let overlapsEvent = day.events.contains { event in
                event.start < hourEnd && event.end > hour.hourStart
            }
            guard overlapsEvent else { continue }

            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let when = formatter.string(from: hour.hourStart).lowercased()

            return AIInsight(
                dayKey: day.dayKey,
                dateGenerated: day.now,
                text: "Bring an umbrella — rain at \(when)",
                colorHex: InsightKind.weather.colorHex,
                tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                kind: .weather,
                actionURL: "weather://",
                priority: InsightKind.weather.defaultPriority
            )
        }

        return nil
    }
}

// MARK: - Live WeatherKit implementation

/// Production `WeatherProviding` impl. Wraps `WeatherService.shared`.
/// Requires `com.apple.developer.weatherkit` entitlement at runtime
/// (added in Task 12); without it, the calls throw and we return an
/// empty forecast → the generator emits nil.
@MainActor
final class LiveWeatherProvider: WeatherProviding {
    private let manager: CLLocationManager

    init() {
        self.manager = CLLocationManager()
    }

    func currentLocation() async -> CLLocation? {
        manager.location
    }

    func hourlyPrecipitation(for location: CLLocation, day: Date) async -> [HourlyPrecipitation] {
        #if canImport(WeatherKit)
        if #available(iOS 26.0, *) {
            do {
                let weather = try await WeatherService.shared.weather(for: location)
                let dayStart = Calendar.current.startOfDay(for: day)
                let dayEnd = dayStart.addingTimeInterval(24 * 3600)
                return weather.hourlyForecast.forecast
                    .filter { $0.date >= dayStart && $0.date < dayEnd }
                    .map {
                        HourlyPrecipitation(hourStart: $0.date,
                                             precipChance: $0.precipitationChance)
                    }
            } catch {
                return []
            }
        }
        #endif
        return []
    }
}
