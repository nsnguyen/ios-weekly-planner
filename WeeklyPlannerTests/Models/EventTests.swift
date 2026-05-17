import Foundation
import XCTest
@testable import WeeklyPlanner

final class EventTests: XCTestCase {
    func testEventDurationHours() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let end = start.addingTimeInterval(1.5 * 3600)
        let event = Event(title: "Standup", start: start, end: end, category: .work)
        XCTAssertEqual(event.durationHours, 1.5, accuracy: 0.0001)
    }

    func testEventInkColorWorkInCreamThemeIsBlueInk() {
        let event = Event(title: "Standup", start: .init(), end: .init(), category: .work)
        XCTAssertEqual(event.inkColor(theme: .cream).rgbaBytes, PaperTheme.cream.blueInk.rgbaBytes)
    }

    func testCategoryAccessorRoundTrip() {
        let event = Event(title: "Travel", start: .init(), end: .init(), category: .travel)
        XCTAssertEqual(event.category, .travel)
        event.category = .health
        XCTAssertEqual(event.category, .health)
        XCTAssertEqual(event.categoryRaw, "health")
    }

    func testSourceAccessorRoundTrip() {
        let event = Event(title: "From Gmail",
                          start: .init(),
                          end: .init(),
                          category: .work,
                          source: .gmail)
        XCTAssertEqual(event.source, .gmail)
        event.source = .appleMail
        XCTAssertEqual(event.source, .appleMail)
        XCTAssertEqual(event.sourceRaw, "appleMail")
    }

    /// Reminder is the value type embedded in `Event.reminders`. Round-trip
    /// it through JSON to verify the Codable conformance the spec calls for.
    func testReminderEncodingRoundTrip() throws {
        let original: [Reminder] = [
            .timeBefore(minutes: 15),
            .onArrive(LocationReminder(name: "Office", latitude: 37.7, longitude: -122.4, radiusMeters: 150)),
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([Reminder].self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testWeekdayIndexForSaturdayIsFive() {
        // Saturday, May 16, 2026
        let saturday = Self.may2026(day: 16)
        let event = Event(title: "Brunch", start: saturday, end: saturday, category: .personal)
        XCTAssertEqual(event.weekdayIndex(in: WeekMath.mondayCalendar()), 5)
    }

    // MARK: - Helpers

    private static func may2026(day: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = day
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
