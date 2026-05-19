import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class ScanInboxToolTests: XCTestCase {
    private var container: ModelContainer!
    private var inbox: SwiftDataInboxStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        inbox = SwiftDataInboxStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        inbox = nil
        container = nil
        try await super.tearDown()
    }

    func testReturnsPendingSuggestionsForRequestedWeek() async throws {
        let today = Self.may16_2026(hour: 12)
        let proposed = Self.may16_2026(hour: 9)
        let suggestion = InboxSuggestion(
            gmailMessageID: "msg-1",
            proposedStart: proposed,
            proposedEnd: proposed.addingTimeInterval(1800),
            title: "Dentist follow-up",
            fromName: "Mei",
            fromEmail: "mei@example.com",
            category: .health,
            subject: "Confirm dentist",
            bodySnippet: "Hi — can we confirm…"
        )
        try await inbox.upsert(suggestion)

        let tool = ScanInboxTool(store: inbox)
        let results = try await tool.run(weekOffset: 0, today: today, limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Dentist follow-up")
        XCTAssertEqual(results.first?.fromName, "Mei")
        XCTAssertEqual(results.first?.subject, "Confirm dentist")
    }

    func testRespectsLimit() async throws {
        let today = Self.may16_2026(hour: 12)
        for i in 0 ..< 6 {
            let proposed = Self.may16_2026(hour: 9 + i)
            let suggestion = InboxSuggestion(
                gmailMessageID: "msg-\(i)",
                proposedStart: proposed,
                proposedEnd: proposed.addingTimeInterval(1800),
                title: "Suggestion \(i)",
                fromName: "Sender \(i)",
                fromEmail: "s\(i)@example.com",
                category: .personal,
                subject: "Subject \(i)"
            )
            try await inbox.upsert(suggestion)
        }
        let tool = ScanInboxTool(store: inbox)
        let results = try await tool.run(weekOffset: 0, today: today, limit: 3)
        XCTAssertEqual(results.count, 3)
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
