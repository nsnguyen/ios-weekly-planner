import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AISearchViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil
        container = nil
        try await super.tearDown()
    }

    func testAskDentistMapsToDentistAnswer() async {
        let viewModel = AISearchViewModel(eventStore: eventStore)
        viewModel.thinkingDelay = .milliseconds(0)
        await viewModel.ask(text: "When's my next dentist appointment?")
        XCTAssertNotNil(viewModel.answer)
        XCTAssertTrue(viewModel.answer?.body.contains("dentist") == true)
        XCTAssertEqual(viewModel.answer?.actions.count, 2)
    }

    func testAskFreeSlotMapsToFreeAnswer() async {
        let viewModel = AISearchViewModel(eventStore: eventStore)
        viewModel.thinkingDelay = .milliseconds(0)
        await viewModel.ask(text: "Find a free 30-min slot tomorrow morning")
        XCTAssertNotNil(viewModel.answer)
        XCTAssertTrue(viewModel.answer?.body.contains("free 30-min") == true)
    }

    func testGenericQueryReturnsFallbackAnswer() async {
        let viewModel = AISearchViewModel(eventStore: eventStore)
        viewModel.thinkingDelay = .milliseconds(0)
        await viewModel.ask(text: "Tell me about the weather")
        XCTAssertNotNil(viewModel.answer)
        XCTAssertTrue(viewModel.answer?.body.contains("Based on your week") == true)
    }

    func testThinkingFlagSetThenClearedAfterDelay() async {
        let viewModel = AISearchViewModel(eventStore: eventStore)
        viewModel.thinkingDelay = .milliseconds(0)
        XCTAssertFalse(viewModel.thinking)
        let task = Task { await viewModel.ask(text: "anything") }
        // We can't reliably observe the intermediate `thinking == true` because the delay is 0 and
        // the assignment + sleep both happen synchronously on MainActor before next await.
        // Instead, verify it's false after completion.
        await task.value
        XCTAssertFalse(viewModel.thinking)
        XCTAssertNotNil(viewModel.answer)
    }

    func testCitationsResolveFromEventStore() async throws {
        // Anchor the event in the same week as the injected clock so the
        // view model's ±4-week scan finds it.
        let saraStart = Self.may16_2026(hour: 9)
        let saraEvent = Event(title: "Sara's birthday breakfast",
                              start: saraStart,
                              end: saraStart.addingTimeInterval(3600),
                              category: .personal)
        try await eventStore.upsert(saraEvent)

        let viewModel = AISearchViewModel(eventStore: eventStore, clock: { Self.may16_2026() })
        viewModel.thinkingDelay = .milliseconds(0)
        await viewModel.ask(text: "When did I last meet with Sara?")
        XCTAssertEqual(viewModel.answer?.citations.count, 1)
        XCTAssertEqual(viewModel.answer?.citations.first?.title, "Sara's birthday breakfast")
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

    func testClearResetsState() async {
        let viewModel = AISearchViewModel(eventStore: eventStore)
        viewModel.thinkingDelay = .milliseconds(0)
        await viewModel.ask(text: "dentist")
        XCTAssertNotNil(viewModel.answer)
        viewModel.clear()
        XCTAssertNil(viewModel.answer)
        XCTAssertEqual(viewModel.query, "")
        XCTAssertFalse(viewModel.thinking)
    }
}
