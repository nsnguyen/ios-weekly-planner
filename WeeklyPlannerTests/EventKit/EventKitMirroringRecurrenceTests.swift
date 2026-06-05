import EventKit
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventKitMirroringRecurrenceTests: XCTestCase {
    private var container: ModelContainer!
    private var base: SwiftDataEventStore!
    private var gateway: FakeEventKitGateway!
    private var store: EventKitMirroringEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        base = SwiftDataEventStore(context: container.mainContext)
        gateway = FakeEventKitGateway()
        store = EventKitMirroringEventStore(base: base,
                                            gateway: gateway,
                                            calendarManager: CategoryCalendarManager(gateway: gateway))
    }

    override func tearDown() async throws {
        store = nil
        gateway = nil
        base = nil
        container = nil
        try await super.tearDown()
    }

    private func makeWeekly(title: String = "Gym") -> Event {
        Event(title: title,
              start: Date(timeIntervalSinceReferenceDate: 800_000_000),
              end: Date(timeIntervalSinceReferenceDate: 800_003_600),
              category: .health,
              recurrence: Recurrence(frequency: .weekly))
    }

    func testUpsertRecurringEventSavesRuleWithFutureSpan() async throws {
        try await store.upsert(makeWeekly())

        let saved = try XCTUnwrap(gateway.savedEvents.last)
        XCTAssertEqual(saved.span, .futureEvents,
                       "Recurring saves must apply to the whole series")
        XCTAssertEqual(saved.event.recurrenceRules?.first?.frequency, .weekly)
    }

    func testUpsertSingleEventSavesWithThisEventSpan() async throws {
        let single = Event(title: "One-off",
                           start: Date(timeIntervalSinceReferenceDate: 800_000_000),
                           end: Date(timeIntervalSinceReferenceDate: 800_003_600),
                           category: .personal)
        try await store.upsert(single)

        let saved = try XCTUnwrap(gateway.savedEvents.last)
        XCTAssertEqual(saved.span, .thisEvent)
        XCTAssertTrue(saved.event.recurrenceRules?.isEmpty ?? true)
    }

    func testDeleteOccurrenceExcludesLocallyEvenWithoutEKMatch() async throws {
        let weekly = makeWeekly()
        try await store.upsert(weekly)
        let occurrence = weekly.start.addingTimeInterval(7 * 86_400)

        try await store.deleteOccurrence(eventID: weekly.id, occurrenceStart: occurrence)

        let master = try await base.event(id: weekly.id)
        XCTAssertEqual(master?.excludedOccurrenceStarts, [occurrence],
                       "Local exclusion must persist regardless of EK detach success")
    }
}
