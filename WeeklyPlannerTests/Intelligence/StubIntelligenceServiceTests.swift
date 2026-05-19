import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class StubIntelligenceServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var events: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        events = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        events = nil; container = nil
        try await super.tearDown()
    }

    func testDentistQueryReturnsCannedBodyAndCitationFromStore() async throws {
        let start = Self.may16_2026(hour: 9)
        try await events.upsert(Event(title: "Dentist follow-up", start: start,
                                      end: start.addingTimeInterval(1800), category: .health))
        let service = StubIntelligenceService(eventStore: events, clock: { Self.may16_2026() })

        let answer = try await service.ask(
            query: "When's my next dentist appointment?",
            context: PlannerContext(now: Self.may16_2026(),
                                    viewedWeekOffset: 0,
                                    maxResponseTokens: 256,
                                    appleIntelligenceEnabled: true)
        )
        XCTAssertTrue(answer.body.contains("dentist"))
        XCTAssertEqual(answer.citations.first?.title, "Dentist follow-up")
        XCTAssertEqual(answer.actions.count, 2)
    }

    func testAvailabilityHonorsAppleIntelligenceEnabled() async {
        let service = StubIntelligenceService(eventStore: events, clock: { Self.may16_2026() })
        let disabled = await service.availability(context: PlannerContext(
            now: Self.may16_2026(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: false
        ))
        XCTAssertEqual(disabled, .unavailable(.userDisabled))
        let enabled = await service.availability(context: PlannerContext(
            now: Self.may16_2026(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: true
        ))
        XCTAssertEqual(enabled, .available)
    }

    func testStreamingDefaultEmitsSingleFinalDelta() async throws {
        let service = StubIntelligenceService(eventStore: events, clock: { Self.may16_2026() })
        var deltas: [AnswerDelta] = []
        for try await delta in service.streamAsk(
            query: "summarize my week",
            context: PlannerContext.default)
        {
            deltas.append(delta)
        }
        XCTAssertEqual(deltas.count, 1)
        XCTAssertTrue(deltas[0].isFinal)
        XCTAssertFalse(deltas[0].textChunk.isEmpty)
    }

    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
