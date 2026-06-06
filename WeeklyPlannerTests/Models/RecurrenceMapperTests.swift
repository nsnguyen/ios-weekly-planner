import EventKit
import XCTest
@testable import WeeklyPlanner

final class RecurrenceMapperTests: XCTestCase {
    func testEachFrequencyMapsBothWays() {
        let pairs: [(RecurrenceFrequency, EKRecurrenceFrequency)] = [
            (.daily, .daily), (.weekly, .weekly), (.monthly, .monthly), (.yearly, .yearly),
        ]
        for (ours, theirs) in pairs {
            let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: ours))
            XCTAssertEqual(rule.frequency, theirs)
            XCTAssertEqual(rule.interval, 1)
            XCTAssertNil(rule.recurrenceEnd)

            let back = RecurrenceMapper.toRecurrence([rule])
            XCTAssertEqual(back, Recurrence(frequency: ours))
        }
    }

    func testIntervalGreaterThanOnePreserved() {
        let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: .weekly, interval: 3))
        XCTAssertEqual(rule.interval, 3)
        XCTAssertEqual(RecurrenceMapper.toRecurrence([rule])?.interval, 3)
    }

    func testEndOnDateRoundTrips() {
        let endDate = Date(timeIntervalSince1970: 1_790_000_000)
        let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: .daily, end: .onDate(endDate)))
        XCTAssertNotNil(rule.recurrenceEnd?.endDate)

        let back = RecurrenceMapper.toRecurrence([rule])
        guard case let .onDate(date)? = back?.end else {
            return XCTFail("Expected .onDate end, got \(String(describing: back?.end))")
        }
        // EventKit normalizes the end date; same calendar day is the contract.
        XCTAssertEqual(Calendar.current.startOfDay(for: date),
                       Calendar.current.startOfDay(for: endDate))
    }

    func testEndAfterCountRoundTrips() {
        let rule = RecurrenceMapper.toEKRule(Recurrence(frequency: .monthly, end: .afterCount(5)))
        XCTAssertEqual(rule.recurrenceEnd?.occurrenceCount, 5)
        XCTAssertEqual(RecurrenceMapper.toRecurrence([rule])?.end, .afterCount(5))
    }

    func testNilAndEmptyRulesMapToNil() {
        XCTAssertNil(RecurrenceMapper.toRecurrence(nil))
        XCTAssertNil(RecurrenceMapper.toRecurrence([]))
    }

    func testComplexRuleOutsideSubsetMapsToNil() {
        // "Weekly on Mon+Wed" — a BYDAY set we don't model.
        let complex = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.monday), EKRecurrenceDayOfWeek(.wednesday)],
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil)
        XCTAssertNil(RecurrenceMapper.toRecurrence([complex]))
    }

    func testWeeklySingleDayOfWeekIsAcceptedAsPlainWeekly() {
        // Other apps commonly emit weekly rules carrying the anchor weekday.
        let single = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 2,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.friday)],
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil)
        XCTAssertEqual(RecurrenceMapper.toRecurrence([single]),
                       Recurrence(frequency: .weekly, interval: 2))
    }
}
