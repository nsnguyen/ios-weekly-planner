import EventKit
import SwiftData
import XCTest
@testable import WeeklyPlanner

/// Verifies the loop-prevention invariant: Google-Calendar-sourced events
/// must NEVER be mirrored to EventKit. If they were, the EventKit reconciler
/// would re-import them and create a loop.
@MainActor
final class GCalMirrorSkipTests: XCTestCase {
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

    // MARK: - Helpers

    private func makeGCalEvent(title: String = "GCal Meeting") -> Event {
        Event(title: title,
              start: Date(timeIntervalSinceReferenceDate: 800_000_000),
              end: Date(timeIntervalSinceReferenceDate: 800_003_600),
              category: .personal,
              source: .googleCalendar)
    }

    private func makeManualEvent(title: String = "Manual Task") -> Event {
        Event(title: title,
              start: Date(timeIntervalSinceReferenceDate: 800_010_000),
              end: Date(timeIntervalSinceReferenceDate: 800_013_600),
              category: .personal,
              source: .manual)
    }

    // MARK: - Tests

    func testUpsertGCalEvent_storesInBase_skipsGateway() async throws {
        let event = makeGCalEvent()

        try await store.upsert(event)

        // Must be persisted in SwiftData
        let fetched = try await base.event(id: event.id)
        XCTAssertNotNil(fetched, "Google-Calendar event must be saved in the base store")
        XCTAssertEqual(fetched?.title, "GCal Meeting")

        // Must NOT touch the EventKit gateway
        XCTAssertTrue(gateway.savedEvents.isEmpty,
                      "EventKit gateway.save must NOT be called for .googleCalendar source (loop prevention)")
    }

    func testDeleteGCalEvent_removesFromBase_skipsGateway() async throws {
        let event = makeGCalEvent()
        // Insert directly into base so delete has something to remove
        try await base.upsert(event)

        try await store.delete(id: event.id)

        // Must be gone from SwiftData
        let fetched = try await base.event(id: event.id)
        XCTAssertNil(fetched, "Google-Calendar event must be deleted from the base store")

        // Must NOT touch the EventKit gateway
        XCTAssertTrue(gateway.removedEvents.isEmpty,
                      "EventKit gateway.remove must NOT be called for .googleCalendar source (loop prevention)")
    }

    func testUpsertManualEvent_callsGateway() async throws {
        // Sanity: the skip is source-specific, not a blanket disable.
        // A .manual event must still reach the gateway.
        let event = makeManualEvent()

        try await store.upsert(event)

        XCTAssertFalse(gateway.savedEvents.isEmpty,
                       "EventKit gateway.save MUST be called for .manual source")
    }
}
