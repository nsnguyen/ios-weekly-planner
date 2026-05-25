import Foundation
import CoreLocation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class WeatherInsightGeneratorTests: XCTestCase {
    private func makeContext(now: Date, events: [Event]) -> DayContext {
        DayContext(weekOffset: 0, dayIdx: 5,
                   events: events, inbox: [],
                   now: now, appleIntelligenceEnabled: true)
    }

    private func event(starts: Date, title: String = "Meeting") -> Event {
        Event(title: title, start: starts,
              end: starts.addingTimeInterval(3600),
              category: .personal)
    }

    func testEmitsUmbrellaWhenPrecipChanceHigh() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let rainAt = now.addingTimeInterval(2 * 3600)
        let provider = FakeWeatherProvider(forecast: [
            HourlyPrecipitation(hourStart: rainAt, precipChance: 0.8)
        ])
        let evt = event(starts: rainAt)
        let gen = WeatherInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight?.text.contains("umbrella") ?? false)
        XCTAssertEqual(insight?.kind, .weather)
        XCTAssertEqual(insight?.priority, 1)
        XCTAssertEqual(insight?.actionURL, "weather://")
    }

    func testNilWhenNoRainInWindow() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeWeatherProvider(forecast: [
            HourlyPrecipitation(hourStart: now, precipChance: 0.1)
        ])
        let gen = WeatherInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [
            event(starts: now.addingTimeInterval(3600))
        ]))
        XCTAssertNil(insight)
    }

    func testNilWhenNoEvents() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeWeatherProvider(forecast: [
            HourlyPrecipitation(hourStart: now, precipChance: 0.9)
        ])
        let gen = WeatherInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: []))
        XCTAssertNil(insight, "Don't emit a weather sticky on a day with no events")
    }
}

@MainActor
private final class FakeWeatherProvider: WeatherProviding {
    let forecast: [HourlyPrecipitation]
    init(forecast: [HourlyPrecipitation]) { self.forecast = forecast }
    func hourlyPrecipitation(for _: CLLocation, day _: Date) async -> [HourlyPrecipitation] {
        forecast
    }
    func currentLocation() async -> CLLocation? {
        CLLocation(latitude: 37.78, longitude: -122.41)
    }
}
