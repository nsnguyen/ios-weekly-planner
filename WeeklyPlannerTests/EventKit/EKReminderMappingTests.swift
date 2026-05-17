import EventKit
import Foundation
import XCTest
@testable import WeeklyPlanner

final class EKReminderMappingTests: XCTestCase {
    private let scratchStore = EKEventStore()

    private func makeBlankReminder() -> EKReminder {
        EKReminder(eventStore: scratchStore)
    }

    // MARK: - Priority codec

    func testPriorityToEKMatchesRFC5545() {
        XCTAssertEqual(EKReminderMapping.priorityToEK(.high), 1)
        XCTAssertEqual(EKReminderMapping.priorityToEK(.med), 5)
        XCTAssertEqual(EKReminderMapping.priorityToEK(.low), 9)
    }

    func testPriorityFromEKBucketsCorrectly() {
        XCTAssertEqual(EKReminderMapping.priorityFromEK(0), .med)
        XCTAssertEqual(EKReminderMapping.priorityFromEK(1), .high)
        XCTAssertEqual(EKReminderMapping.priorityFromEK(3), .high)
        XCTAssertEqual(EKReminderMapping.priorityFromEK(5), .med)
        XCTAssertEqual(EKReminderMapping.priorityFromEK(9), .low)
    }

    // MARK: - Round-trip

    func testOutboundApplyPreservesCoreFields() throws {
        let due = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 16, hour: 9)))
        let task = TaskItem(title: "Buy milk",
                            due: due,
                            priority: .high,
                            category: .personal,
                            reminderText: "From Marina")
        let reminder = makeBlankReminder()
        EKReminderMapping.apply(task, to: reminder, calendar: nil)

        XCTAssertEqual(reminder.title, "Buy milk")
        XCTAssertEqual(reminder.priority, 1)
        XCTAssertNotNil(reminder.dueDateComponents)
        XCTAssertEqual(reminder.dueDateComponents?.year, 2026)
        XCTAssertEqual(reminder.dueDateComponents?.month, 5)
        XCTAssertEqual(reminder.dueDateComponents?.day, 16)
    }

    func testNotesMetaRoundTripPreservesCategoryAndText() {
        let task = TaskItem(title: "Run",
                            due: .init(),
                            priority: .med,
                            category: .health,
                            reminderText: "Park entrance")
        let reminder = makeBlankReminder()
        EKReminderMapping.apply(task, to: reminder, calendar: nil)

        let decoded = EKReminderMapping.toTaskItem(reminder)
        XCTAssertEqual(decoded.title, "Run")
        XCTAssertEqual(decoded.category, .health)
        XCTAssertEqual(decoded.reminderText, "Park entrance")
        XCTAssertEqual(decoded.priority, .med)
    }

    func testLocationReminderRoundTrip() {
        let location = LocationReminder(name: "Marina", latitude: 37.81, longitude: -122.45, radiusMeters: 200)
        let task = TaskItem(title: "Pick up keys",
                            due: .init(),
                            category: .personal,
                            locationReminder: location)
        let reminder = makeBlankReminder()
        EKReminderMapping.apply(task, to: reminder, calendar: nil)

        XCTAssertEqual(reminder.alarms?.count, 1)
        XCTAssertEqual(reminder.alarms?.first?.proximity, .enter)
        XCTAssertEqual(reminder.alarms?.first?.structuredLocation?.title, "Marina")
        XCTAssertEqual(reminder.alarms?.first?.structuredLocation?.radius, 200)
    }
}
