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

    /// Phase 32 (#49): fallback copy uses the product voice ("Ask the
    /// planner" / "on-device AI"), not Apple's framework branding.
    func testFallbackMessagesAreHonestAndUseProductVoice() {
        XCTAssertEqual(
            AvailabilityState.unavailable(.deviceNotEligible).fallbackMessage,
            "On-device AI isn't available on this device. Showing canned suggestions."
        )
        XCTAssertEqual(
            AvailabilityState.unavailable(.modelNotReady).fallbackMessage,
            "On-device AI is still warming up. Showing canned suggestions."
        )
        XCTAssertEqual(
            AvailabilityState.unavailable(.userDisabled).fallbackMessage,
            "Ask the planner is turned off in Settings. Showing canned suggestions."
        )
        // Intentional exception (flagged for Phase 40): this case points the
        // user at the REAL iOS Settings toggle, which Apple names "Apple
        // Intelligence" — renaming it here would hide the actual setting.
        XCTAssertEqual(
            AvailabilityState.unavailable(.appleIntelligenceNotEnabled).fallbackMessage,
            "Enable Apple Intelligence in iOS Settings to get personalized answers. Showing canned suggestions."
        )
    }
}
