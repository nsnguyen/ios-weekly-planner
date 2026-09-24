import XCTest
@testable import WeeklyPlanner

final class RecurrencePresetTests: XCTestCase {
    func testPresetOrderAndDisplayNames() {
        XCTAssertEqual(RecurrencePreset.allCases.map(\.displayName),
                       ["None", "Daily", "Weekly", "Every 2 weeks", "Monthly", "Yearly", "Custom…"])
    }

    func testPresetToRecurrenceMapping() {
        XCTAssertNil(RecurrencePreset.none.recurrence)
        XCTAssertEqual(RecurrencePreset.daily.recurrence?.frequency, .daily)
        XCTAssertEqual(RecurrencePreset.weekly.recurrence?.frequency, .weekly)
        XCTAssertEqual(RecurrencePreset.weekly.recurrence?.interval, 1)
        XCTAssertEqual(RecurrencePreset.everyTwoWeeks.recurrence?.frequency, .weekly)
        XCTAssertEqual(RecurrencePreset.everyTwoWeeks.recurrence?.interval, 2)
        XCTAssertEqual(RecurrencePreset.monthly.recurrence?.frequency, .monthly)
        XCTAssertEqual(RecurrencePreset.yearly.recurrence?.frequency, .yearly)
        // Custom seeds a starting rule the steppers then refine.
        XCTAssertEqual(RecurrencePreset.custom.recurrence?.frequency, .weekly)
    }

    func testMatchingRoundTrip() {
        XCTAssertEqual(RecurrencePreset.matching(nil), RecurrencePreset.none)
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .weekly, interval: 2)), .everyTwoWeeks)
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .daily)), .daily)
        // Off-preset combos surface as Custom.
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .weekly, interval: 3)), .custom)
        XCTAssertEqual(RecurrencePreset.matching(Recurrence(frequency: .monthly, interval: 2)), .custom)
    }
}
