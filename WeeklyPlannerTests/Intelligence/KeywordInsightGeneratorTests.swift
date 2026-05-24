import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class KeywordInsightGeneratorTests: XCTestCase {
    private func makeContext(events: [Event] = [],
                              appleIntelligenceEnabled: Bool = true) -> DayContext
    {
        DayContext(weekOffset: 0,
                   dayIdx: 5,
                   events: events,
                   inbox: [],
                   now: Date(timeIntervalSince1970: 1_780_000_000),
                   appleIntelligenceEnabled: appleIntelligenceEnabled)
    }

    private func event(title: String, id: UUID = UUID()) -> Event {
        Event(id: id,
              title: title,
              start: Date(timeIntervalSince1970: 1_780_000_000),
              end: Date(timeIntervalSince1970: 1_780_003_600),
              category: .personal)
    }

    func testEmitsForBirthdayKeyword() async {
        let id = UUID()
        let fake = FakeKeywordModel(result: .init(
            text: "Don't forget Sara's gift!",
            relatedEventID: id.uuidString,
            confidence: 0.9))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "Sara's birthday", id: id)]))
        XCTAssertEqual(insight?.text, "Don't forget Sara's gift!")
        XCTAssertEqual(insight?.kind, .keyword)
        XCTAssertEqual(insight?.actionURL, "weeklyplanner://event/\(id.uuidString)")
        XCTAssertEqual(insight?.priority, 2)
    }

    func testDropsLowConfidence() async {
        let fake = FakeKeywordModel(result: .init(text: "uncertain",
                                                   relatedEventID: "",
                                                   confidence: 0.4))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "Meeting")]))
        XCTAssertNil(insight)
    }

    func testNilWhenAppleIntelligenceOff() async {
        let fake = FakeKeywordModel(result: .init(text: "should not run",
                                                   relatedEventID: "",
                                                   confidence: 0.9))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "M")],
                                                          appleIntelligenceEnabled: false))
        XCTAssertNil(insight)
        XCTAssertFalse(fake.wasCalled,
                       "Should short-circuit before invoking the model when AI is off")
    }

    func testGenerableEmptyStringSentinelHonored() async {
        let fake = FakeKeywordModel(result: .init(text: "Day-wide reminder",
                                                   relatedEventID: "",
                                                   confidence: 0.8))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "M")]))
        XCTAssertNotNil(insight)
        XCTAssertNil(insight?.actionURL,
                     "Empty-string relatedEventID sentinel → no deep link")
    }
}

@MainActor
private final class FakeKeywordModel: KeywordInsightModeling {
    let result: KeywordInsightDraft
    private(set) var wasCalled = false

    init(result: KeywordInsightDraft) { self.result = result }

    func generateKeyword(prompt _: String, day _: DayContext) async throws -> KeywordInsightDraft? {
        wasCalled = true
        return result
    }
}
