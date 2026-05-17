import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class DayPageViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var inboxStore: SwiftDataInboxStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil
        inboxStore = nil
        container = nil
        try await super.tearDown()
    }

    /// Saturday May 16, 2026 — same anchor used across the planner test
    /// suite so week math is deterministic.
    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    /// Friday May 15, 2026.
    private static func may15_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    private func makeViewModel(weekOffset: Int, dayIdx: Int, clock: @escaping () -> Date) -> DayPageViewModel {
        DayPageViewModel(weekOffset: weekOffset,
                         dayIdx: dayIdx,
                         eventStore: eventStore,
                         inboxStore: inboxStore,
                         clock: clock)
    }

    // MARK: - Events

    func testRefreshLoadsEventsForGivenDayIdx() async throws {
        let sat9 = Event(title: "Sat 9 AM",
                         start: Self.may16_2026(hour: 9),
                         end: Self.may16_2026(hour: 10),
                         category: .work)
        let sat11 = Event(title: "Sat 11 AM",
                          start: Self.may16_2026(hour: 11),
                          end: Self.may16_2026(hour: 12),
                          category: .work)
        let fri = Event(title: "Fri noon",
                        start: Self.may15_2026(hour: 12),
                        end: Self.may15_2026(hour: 13),
                        category: .work)
        try await eventStore.upsert(sat9)
        try await eventStore.upsert(sat11)
        try await eventStore.upsert(fri)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()

        XCTAssertEqual(vm.events.count, 2)
        XCTAssertEqual(vm.events.map(\.title), ["Sat 9 AM", "Sat 11 AM"])
        XCTAssertNil(vm.loadError)
    }

    func testEventsSortedByStartAscending() async throws {
        let late = Event(title: "Three PM",
                         start: Self.may16_2026(hour: 15),
                         end: Self.may16_2026(hour: 16),
                         category: .work)
        let early = Event(title: "Nine AM",
                          start: Self.may16_2026(hour: 9),
                          end: Self.may16_2026(hour: 10),
                          category: .work)
        let mid = Event(title: "Eleven AM",
                        start: Self.may16_2026(hour: 11),
                        end: Self.may16_2026(hour: 12),
                        category: .work)
        try await eventStore.upsert(late)
        try await eventStore.upsert(early)
        try await eventStore.upsert(mid)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()

        let starts = vm.events.map(\.start)
        XCTAssertEqual(starts, starts.sorted())
        XCTAssertEqual(vm.events.map(\.title), ["Nine AM", "Eleven AM", "Three PM"])
    }

    // MARK: - isToday

    func testIsTodayTrueForCurrentWeekSaturday() {
        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        XCTAssertTrue(vm.isToday)
    }

    func testIsTodayFalseForOtherDay() {
        let vm = makeViewModel(weekOffset: 0, dayIdx: 3, clock: { Self.may16_2026() })
        XCTAssertFalse(vm.isToday)
    }

    func testIsTodayFalseForOtherWeek() {
        let vm = makeViewModel(weekOffset: 1, dayIdx: 5, clock: { Self.may16_2026() })
        XCTAssertFalse(vm.isToday)
    }

    // MARK: - Inbox

    func testAcceptSuggestionMarksItAcceptedAndRemovesFromInbox() async throws {
        let suggestion = InboxSuggestion(gmailMessageID: "msg-1",
                                         proposedStart: Self.may16_2026(hour: 14),
                                         title: "Coffee with Dana",
                                         fromName: "Dana",
                                         fromEmail: "dana@example.com",
                                         subject: "coffee?",
                                         status: .pending)
        try await inboxStore.upsert(suggestion)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()
        XCTAssertEqual(vm.inbox.count, 1)

        await vm.accept(suggestionID: suggestion.id)
        XCTAssertEqual(vm.inbox.count, 0)

        let stored = try await inboxStore.suggestion(id: suggestion.id)
        XCTAssertEqual(stored?.status, .accepted)
    }

    func testDismissSuggestionRemovesFromInbox() async throws {
        let suggestion = InboxSuggestion(gmailMessageID: "msg-2",
                                         proposedStart: Self.may16_2026(hour: 16),
                                         title: "Optional drinks",
                                         fromName: "Sam",
                                         fromEmail: "sam@example.com",
                                         subject: "drinks?",
                                         status: .pending)
        try await inboxStore.upsert(suggestion)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()
        XCTAssertEqual(vm.inbox.count, 1)

        await vm.dismiss(suggestionID: suggestion.id)
        XCTAssertEqual(vm.inbox.count, 0)

        let stored = try await inboxStore.suggestion(id: suggestion.id)
        XCTAssertEqual(stored?.status, .dismissed)
    }

    func testInboxFilteredByDayIdx() async throws {
        let friSuggestion = InboxSuggestion(gmailMessageID: "fri",
                                            proposedStart: Self.may15_2026(hour: 10),
                                            title: "Friday standup",
                                            fromName: "Alex",
                                            fromEmail: "alex@example.com",
                                            subject: "standup",
                                            status: .pending)
        let satSuggestion = InboxSuggestion(gmailMessageID: "sat",
                                            proposedStart: Self.may16_2026(hour: 10),
                                            title: "Saturday brunch",
                                            fromName: "Mei",
                                            fromEmail: "mei@example.com",
                                            subject: "brunch",
                                            status: .pending)
        try await inboxStore.upsert(friSuggestion)
        try await inboxStore.upsert(satSuggestion)

        let vm = makeViewModel(weekOffset: 0, dayIdx: 5, clock: { Self.may16_2026() })
        await vm.refresh()

        XCTAssertEqual(vm.inbox.count, 1)
        XCTAssertEqual(vm.inbox.first?.title, "Saturday brunch")
    }
}
