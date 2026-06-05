import XCTest
@testable import WeeklyPlanner

final class RecurrenceTests: XCTestCase {
    func testCodableRoundTripAllEndModes() throws {
        let cases: [Recurrence] = [
            Recurrence(frequency: .daily),
            Recurrence(frequency: .weekly, interval: 2, end: .afterCount(10)),
            Recurrence(frequency: .monthly, interval: 3, end: .onDate(Date(timeIntervalSince1970: 1_800_000_000))),
            Recurrence(frequency: .yearly, end: .never),
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Recurrence.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    func testIntervalClampsToAtLeastOne() {
        XCTAssertEqual(Recurrence(frequency: .daily, interval: 0).interval, 1)
        XCTAssertEqual(Recurrence(frequency: .daily, interval: -3).interval, 1)
        XCTAssertEqual(Recurrence(frequency: .daily, interval: 4).interval, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(RecurrenceFrequency.daily.displayName, "Daily")
        XCTAssertEqual(RecurrenceFrequency.weekly.displayName, "Weekly")
        XCTAssertEqual(RecurrenceFrequency.monthly.displayName, "Monthly")
        XCTAssertEqual(RecurrenceFrequency.yearly.displayName, "Yearly")
        XCTAssertEqual(RecurrenceFrequency.weekly.unitName, "week")
    }
}
