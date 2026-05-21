import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class DefaultReminderPolicyTests: XCTestCase {
    private func makeEvent() -> Event {
        Event(
            title: "Coffee",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_700_003_600),
            location: nil,
            category: .personal
        )
    }

    private func settings(defaultMinutes: Int?) -> UserSettings {
        UserSettings(defaultReminderMinutes: defaultMinutes)
    }

    func testAppliesDefaultWhenEventHasNoReminders() {
        let event = makeEvent()
        DefaultReminderPolicy.apply(to: event, settings: settings(defaultMinutes: 15))

        XCTAssertEqual(event.reminders.count, 1)
        guard case let .timeBefore(minutes) = event.reminders.first else {
            return XCTFail("Expected .timeBefore")
        }
        XCTAssertEqual(minutes, 15)
    }

    func testNoOpWhenDefaultIsNil() {
        let event = makeEvent()
        DefaultReminderPolicy.apply(to: event, settings: settings(defaultMinutes: nil))

        XCTAssertTrue(event.reminders.isEmpty)
    }

    func testNoOpWhenEventAlreadyHasTimeReminder() {
        let event = makeEvent()
        event.reminders = [.timeBefore(minutes: 60)]

        DefaultReminderPolicy.apply(to: event, settings: settings(defaultMinutes: 15))

        XCTAssertEqual(event.reminders.count, 1)
        guard case let .timeBefore(minutes) = event.reminders.first else {
            return XCTFail("Expected .timeBefore")
        }
        XCTAssertEqual(minutes, 60)
    }
}
