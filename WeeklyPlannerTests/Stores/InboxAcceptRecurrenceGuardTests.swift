import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class InboxAcceptRecurrenceGuardTests: XCTestCase {
    func testAcceptedGmailSuggestionIsSingleOccurrence() async throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        // `eventStore` is an init-time dependency on SwiftDataInboxStore (a
        // private let), so it's wired through the initializer — matching the
        // production app's construction in Phase 18.
        let inboxStore = SwiftDataInboxStore(context: container.mainContext,
                                             eventStore: eventStore)

        // Fixture mirrors the existing InboxStore accept tests' construction.
        let suggestion = InboxSuggestion(
            gmailMessageID: "msg-1",
            proposedStart: Date().addingTimeInterval(86_400),
            proposedEnd: Date().addingTimeInterval(86_400 + 3600),
            title: "Coffee with Alex",
            fromName: "Alex",
            fromEmail: "alex@example.com",
            category: .personal,
            subject: "Coffee?"
        )
        container.mainContext.insert(suggestion)
        try container.mainContext.save()

        try await inboxStore.accept(id: suggestion.id)

        let events = try container.mainContext.fetch(FetchDescriptor<Event>())
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events.first?.recurrence, "Phase 18 path must stay single-occurrence")
        XCTAssertFalse(events.first?.isRecurring ?? true)
    }
}
