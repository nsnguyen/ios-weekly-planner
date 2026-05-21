import XCTest
@testable import WeeklyPlanner

final class GmailQueryBuilderTests: XCTestCase {
    func testDefaultQueryIncludesEventKeywordsAndExcludesCategories() {
        let q = GmailQueryBuilder.defaultQuery(daysBack: 14)

        XCTAssertTrue(q.contains("from:reservations"))
        XCTAssertTrue(q.contains("subject:(invite OR confirmation OR reservation OR ticket OR appointment OR RSVP OR booking)"))
        XCTAssertTrue(q.contains("-category:promotions"))
        XCTAssertTrue(q.contains("-category:social"))
        XCTAssertTrue(q.contains("newer_than:14d"))
    }

    func testDaysBackParameterized() {
        let q = GmailQueryBuilder.defaultQuery(daysBack: 7)
        XCTAssertTrue(q.contains("newer_than:7d"))
    }
}
