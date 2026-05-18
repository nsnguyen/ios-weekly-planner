import XCTest
@testable import WeeklyPlanner

final class AvailabilityTests: XCTestCase {
    func testUnavailableReasonsAreDistinct() {
        let cases: Set<AvailabilityState> = [
            .available,
            .unavailable(.deviceNotEligible),
            .unavailable(.modelNotReady),
            .unavailable(.appleIntelligenceNotEnabled),
            .unavailable(.userDisabled),
        ]
        XCTAssertEqual(cases.count, 5)
    }

    func testIsAvailableShortcut() {
        XCTAssertTrue(AvailabilityState.available.isAvailable)
        XCTAssertFalse(AvailabilityState.unavailable(.userDisabled).isAvailable)
    }

    func testFallbackMessageMatchesSpec() {
        XCTAssertEqual(
            AvailabilityState.unavailable(.deviceNotEligible).fallbackMessage,
            "Apple Intelligence is unavailable on this device. Showing canned suggestions."
        )
        XCTAssertEqual(
            AvailabilityState.unavailable(.userDisabled).fallbackMessage,
            "Apple Intelligence is turned off in Settings. Showing canned suggestions."
        )
    }
}
