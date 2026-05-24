import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EncouragementInsightGeneratorTests: XCTestCase {
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

    func testPromptListsEventTitlesForWeekday() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let events = [
            Event(title: "Standup", start: start,
                  end: start.addingTimeInterval(1800), category: .work),
            Event(title: "Lunch with Mei", start: start.addingTimeInterval(7200),
                  end: start.addingTimeInterval(9000), category: .personal),
        ]
        let prompt = EncouragementInsightGenerator.prompt(weekOffset: 0, dayIdx: 0, events: events)
        XCTAssertTrue(prompt.contains("Monday"))
        XCTAssertTrue(prompt.contains("Standup"))
        XCTAssertTrue(prompt.contains("Lunch with Mei"))
        XCTAssertTrue(prompt.contains("≤ 80 chars"))
    }

    func testEmptyEventsListProducesEmptyDayPrompt() {
        let prompt = EncouragementInsightGenerator.prompt(weekOffset: 0, dayIdx: 5, events: [])
        XCTAssertTrue(prompt.contains("Saturday"))
        XCTAssertTrue(prompt.contains("no events scheduled"))
    }

    func testColorAndTiltAreStableForSameKey() {
        let color1 = EncouragementInsightGenerator.color(weekOffset: 0, dayIdx: 3)
        let color2 = EncouragementInsightGenerator.color(weekOffset: 0, dayIdx: 3)
        let tilt1 = EncouragementInsightGenerator.tilt(weekOffset: 0, dayIdx: 3)
        let tilt2 = EncouragementInsightGenerator.tilt(weekOffset: 0, dayIdx: 3)
        XCTAssertEqual(color1, color2)
        XCTAssertEqual(tilt1, tilt2)
        XCTAssertTrue(["#FFE680", "#C9F0E0", "#FFCCC9"].contains(color1))
        XCTAssertTrue(tilt1 >= -5 && tilt1 <= 5)
    }

    func testGenerateReturnsInsightOnSuccess() async {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = EncouragementInsightGenerator(intelligence: service)
        let ctx = DayContext(weekOffset: 0,
                             dayIdx: 0,
                             events: [],
                             inbox: [],
                             now: Date(),
                             appleIntelligenceEnabled: true)
        let insight = await generator.generate(for: ctx)
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.dayKey, "0:0")
        XCTAssertFalse(insight?.text.isEmpty ?? true)
    }

    func testGenerateReturnsNilWhenAIDisabled() async {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = EncouragementInsightGenerator(intelligence: service,
                                                       settings: { false })
        let ctx = DayContext(weekOffset: 0,
                             dayIdx: 0,
                             events: [],
                             inbox: [],
                             now: Date(),
                             appleIntelligenceEnabled: false)
        let insight = await generator.generate(for: ctx)
        XCTAssertNil(insight)
    }
}
