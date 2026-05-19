import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventSuggestionGeneratorTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil; container = nil
        try await super.tearDown()
    }

    func testPromptIncludesEventMetadata() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let event = Event(title: "Dentist follow-up",
                          start: start,
                          end: start.addingTimeInterval(1800),
                          location: "4th Street Dental",
                          category: .health,
                          attendeesCount: 1,
                          travelMinutes: 20)
        let prompt = EventSuggestionGenerator.prompt(for: event)
        XCTAssertTrue(prompt.contains("Dentist follow-up"))
        XCTAssertTrue(prompt.contains("Location: 4th Street Dental"))
        XCTAssertTrue(prompt.contains("Travel time: 20 minutes"))
        XCTAssertTrue(prompt.contains("Category: health"))
        XCTAssertTrue(prompt.contains("≤ 140 chars"))
    }

    func testGenerateReturnsTrimmedBodyOnSuccess() async throws {
        let event = Event(title: "Dentist follow-up",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_001_800),
                          category: .health)
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = EventSuggestionGenerator(intelligence: service)
        let text = await generator.generate(for: event)
        XCTAssertNotNil(text)
        XCTAssertFalse(text?.isEmpty ?? true)
    }

    func testGenerateReturnsNilWhenAIDisabled() async {
        let event = Event(title: "Dentist follow-up",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_001_800),
                          category: .health)
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = EventSuggestionGenerator(intelligence: service,
                                                  settings: { false })
        let text = await generator.generate(for: event)
        XCTAssertNil(text)
    }
}
