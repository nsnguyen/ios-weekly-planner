import Foundation
import CoreLocation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TravelInsightGeneratorTests: XCTestCase {
    private func event(title: String,
                       location: String?,
                       startsInSeconds offset: TimeInterval,
                       relativeTo now: Date) -> Event
    {
        Event(title: title,
              start: now.addingTimeInterval(offset),
              end: now.addingTimeInterval(offset + 3600),
              location: location,
              category: .personal)
    }

    private func makeContext(now: Date, events: [Event]) -> DayContext {
        DayContext(weekOffset: 0, dayIdx: 5,
                   events: events, inbox: [],
                   now: now,
                   appleIntelligenceEnabled: true)
    }

    func testEmitsForUpcomingEventWithLocation() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeTravelProvider(
            authStatus: .authorizedWhenInUse,
            coordinateForAddress: ["Trick Dog, Mission": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocationValue: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 25 * 60)
        let evt = event(title: "Dentist", location: "Trick Dog, Mission",
                        startsInSeconds: 35 * 60, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight?.text.contains("Leave by") ?? false,
                       "Got: \(insight?.text ?? "nil")")
        XCTAssertTrue(insight?.text.contains("Dentist") ?? false)
        XCTAssertEqual(insight?.kind, .travel)
        XCTAssertEqual(insight?.priority, 0)
        XCTAssertTrue(insight?.actionURL?.hasPrefix("http://maps.apple.com/?daddr=") ?? false)
    }

    func testNilWhenLocationAuthDenied() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeTravelProvider(
            authStatus: .denied,
            coordinateForAddress: ["HQ": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocationValue: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 600)
        let evt = event(title: "M", location: "HQ", startsInSeconds: 30 * 60, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNil(insight)
    }

    func testNilWhenEventBeyond4Hours() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeTravelProvider(
            authStatus: .authorizedWhenInUse,
            coordinateForAddress: ["HQ": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocationValue: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 600)
        let evt = event(title: "Late dinner", location: "HQ",
                        startsInSeconds: 5 * 3600, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNil(insight)
    }

    func testRespectsDepartureThreshold() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeTravelProvider(
            authStatus: .authorizedWhenInUse,
            coordinateForAddress: ["HQ": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocationValue: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 600)
        let evt = event(title: "Future", location: "HQ",
                        startsInSeconds: 3 * 3600, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNil(insight)
    }
}

@MainActor
private final class FakeTravelProvider: TravelProviding {
    let authStatus: CLAuthorizationStatus
    let coordinateForAddress: [String: CLLocationCoordinate2D]
    let currentLocationValue: CLLocation?
    let travelTimeSeconds: TimeInterval?

    init(authStatus: CLAuthorizationStatus,
         coordinateForAddress: [String: CLLocationCoordinate2D],
         currentLocationValue: CLLocation?,
         travelTimeSeconds: TimeInterval?)
    {
        self.authStatus = authStatus
        self.coordinateForAddress = coordinateForAddress
        self.currentLocationValue = currentLocationValue
        self.travelTimeSeconds = travelTimeSeconds
    }

    func locationAuthorizationStatus() -> CLAuthorizationStatus { authStatus }
    func currentLocation() async -> CLLocation? { currentLocationValue }
    func geocode(address: String) async -> CLLocationCoordinate2D? { coordinateForAddress[address] }
    func travelTime(from _: CLLocationCoordinate2D, to _: CLLocationCoordinate2D) async -> TimeInterval? {
        travelTimeSeconds
    }
}
