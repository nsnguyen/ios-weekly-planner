import XCTest
@testable import WeeklyPlanner

final class TimeSpentBarChartTests: XCTestCase {
    func testRowsFromEmptyDictionaryIsEmpty() {
        XCTAssertTrue(TimeSpentBarChart.rows(from: [:]).isEmpty)
    }

    func testRowsFilterOutZeroHourEntries() {
        let rows = TimeSpentBarChart.rows(from: [.work: 0.0, .health: 1.5])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.0, .health)
        XCTAssertEqual(rows.first?.1 ?? 0, 1.5, accuracy: 0.001)
    }

    func testRowsSortedByHoursDescending() {
        let rows = TimeSpentBarChart.rows(from: [.work: 1.5,
                                                  .health: 3.0,
                                                  .personal: 0.75])
        XCTAssertEqual(rows.map(\.0), [.health, .work, .personal])
    }

    func testEmptyStateCopyIsNonEmpty() {
        XCTAssertFalse(TimeSpentBarChart.emptyStateCopy.isEmpty)
    }
}
