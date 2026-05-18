import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class WeekPageViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var taskStore: SwiftDataTaskStore!
    private var inboxStore: SwiftDataInboxStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        taskStore = SwiftDataTaskStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil
        taskStore = nil
        inboxStore = nil
        container = nil
        try await super.tearDown()
    }

    /// Date inside Saturday May 16, 2026 — same anchor used across the
    /// planner test suite so week math is deterministic.
    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    /// Date inside Monday May 11, 2026 (the Monday of the same week).
    private static func may11_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 11
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    private func makeViewModel(weekOffset: Int = 0,
                               clock: @escaping () -> Date = { may16_2026() }) -> WeekPageViewModel
    {
        WeekPageViewModel(weekOffset: weekOffset,
                          eventStore: eventStore,
                          taskStore: taskStore,
                          inboxStore: inboxStore,
                          clock: clock)
    }

    // MARK: - Events

    /// Three events on Saturday + one on Monday should land in
    /// `eventsByDay[5]` and `eventsByDay[0]` respectively. Monday-based
    /// weekday index: 0 = Mon, 5 = Sat.
    func testEventsGroupedByDayIndex() async throws {
        let sat9 = Event(title: "Sat 9 AM",
                         start: Self.may16_2026(hour: 9),
                         end: Self.may16_2026(hour: 10),
                         category: .work)
        let sat11 = Event(title: "Sat 11 AM",
                          start: Self.may16_2026(hour: 11),
                          end: Self.may16_2026(hour: 12),
                          category: .work)
        let sat15 = Event(title: "Sat 3 PM",
                          start: Self.may16_2026(hour: 15),
                          end: Self.may16_2026(hour: 16),
                          category: .personal)
        let mon = Event(title: "Mon noon",
                        start: Self.may11_2026(hour: 12),
                        end: Self.may11_2026(hour: 13),
                        category: .work)
        try await eventStore.upsert(sat9)
        try await eventStore.upsert(sat11)
        try await eventStore.upsert(sat15)
        try await eventStore.upsert(mon)

        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertEqual(vm.eventsByDay[5]?.count, 3)
        XCTAssertEqual(vm.eventsByDay[0]?.count, 1)
        XCTAssertEqual(vm.eventsByDay[5]?.map(\.title), ["Sat 9 AM", "Sat 11 AM", "Sat 3 PM"])
        XCTAssertNil(vm.loadError)
    }

    // MARK: - Tasks

    /// `openTaskCount` should only count tasks where `done == false`.
    func testTaskCountExcludesDone() async throws {
        let open = TaskItem(title: "Water plants",
                            due: Self.may16_2026(hour: 9),
                            done: false,
                            priority: .low,
                            category: .personal)
        let done1 = TaskItem(title: "Confirm reservation",
                             due: Self.may16_2026(hour: 10),
                             done: true,
                             priority: .low,
                             category: .personal)
        let done2 = TaskItem(title: "Pick up dry cleaning",
                             due: Self.may16_2026(hour: 11),
                             done: true,
                             priority: .med,
                             category: .personal)
        try await taskStore.upsert(open)
        try await taskStore.upsert(done1)
        try await taskStore.upsert(done2)

        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertEqual(vm.openTaskCount, 1)
    }

    // MARK: - Inbox

    /// `inboxCount` should mirror the count of pending suggestions returned
    /// by `InboxStoring.pending(forWeekOffset:today:)`.
    func testInboxCountReturnsFromStore() async throws {
        let first = InboxSuggestion(gmailMessageID: "msg-1",
                                    proposedStart: Self.may16_2026(hour: 14),
                                    title: "Coffee with Dana",
                                    fromName: "Dana",
                                    fromEmail: "dana@example.com",
                                    subject: "coffee?",
                                    status: .pending)
        let second = InboxSuggestion(gmailMessageID: "msg-2",
                                     proposedStart: Self.may11_2026(hour: 10),
                                     title: "Standup",
                                     fromName: "Alex",
                                     fromEmail: "alex@example.com",
                                     subject: "standup",
                                     status: .pending)
        try await inboxStore.upsert(first)
        try await inboxStore.upsert(second)

        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertEqual(vm.inboxCount, 2)
    }

    // MARK: - Event count

    /// `eventCount` should equal the sum of events across every weekday bucket.
    func testEventCountIsTotal() async throws {
        let mon = Event(title: "Mon",
                        start: Self.may11_2026(hour: 9),
                        end: Self.may11_2026(hour: 10),
                        category: .work)
        let sat1 = Event(title: "Sat 1",
                         start: Self.may16_2026(hour: 9),
                         end: Self.may16_2026(hour: 10),
                         category: .work)
        let sat2 = Event(title: "Sat 2",
                         start: Self.may16_2026(hour: 11),
                         end: Self.may16_2026(hour: 12),
                         category: .work)
        try await eventStore.upsert(mon)
        try await eventStore.upsert(sat1)
        try await eventStore.upsert(sat2)

        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertEqual(vm.eventCount, 3)
    }
}
