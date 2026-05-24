import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class InboxInsightGeneratorTests: XCTestCase {
    private func makeContext(suggestions: [InboxSuggestion]) -> DayContext {
        DayContext(weekOffset: 0,
                   dayIdx: 5,
                   events: [],
                   inbox: suggestions,
                   now: Date(timeIntervalSince1970: 1_780_000_000),
                   appleIntelligenceEnabled: true)
    }

    /// The plan's test harness assumed a `from:` / `confidence:` init that
    /// doesn't exist on the real `InboxSuggestion` `@Model`. Adapted to the
    /// actual signature (gmailMessageID + fromName/fromEmail + subject).
    private func makeSuggestion(id: String = UUID().uuidString,
                                 title: String = "Trade Confirmations") -> InboxSuggestion {
        InboxSuggestion(gmailMessageID: id,
                        proposedStart: Date(timeIntervalSince1970: 1_780_000_000),
                        title: title,
                        fromName: "Broker",
                        fromEmail: "broker@example.com",
                        category: .work,
                        subject: title)
    }

    func testEmitsCountWhenPending() async {
        let gen = InboxInsightGenerator()
        let suggestions = [makeSuggestion(id: "a"),
                           makeSuggestion(id: "b", title: "Lunch")]
        let insight = await gen.generate(for: makeContext(suggestions: suggestions))
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.text, "2 inbox suggestions for today")
        XCTAssertEqual(insight?.kind, .inbox)
        XCTAssertEqual(insight?.priority, 3)
        XCTAssertEqual(insight?.actionURL, "weeklyplanner://inbox/0:5")
        XCTAssertEqual(insight?.colorHex, "#E0DFFF")
    }

    func testNilWhenZeroPending() async {
        let gen = InboxInsightGenerator()
        let insight = await gen.generate(for: makeContext(suggestions: []))
        XCTAssertNil(insight)
    }

    func testSingularPluralAgreement() async {
        let gen = InboxInsightGenerator()
        let one = await gen.generate(for: makeContext(suggestions: [makeSuggestion(id: "x")]))
        XCTAssertEqual(one?.text, "1 inbox suggestion for today")
        let three = await gen.generate(for: makeContext(suggestions: [
            makeSuggestion(id: "1"),
            makeSuggestion(id: "2", title: "B"),
            makeSuggestion(id: "3", title: "C")
        ]))
        XCTAssertEqual(three?.text, "3 inbox suggestions for today")
    }
}
