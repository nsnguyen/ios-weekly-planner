import XCTest
@testable import WeeklyPlanner

final class SafetyGuardTests: XCTestCase {
    func testTrimsWhitespace() {
        XCTAssertEqual(SafetyGuard.sanitize("   hello   "), "hello")
    }

    func testStripsControlChars() {
        let dirty = "hello\u{0007}world\u{0001}"
        XCTAssertEqual(SafetyGuard.sanitize(dirty), "helloworld")
    }

    func testTruncatesAtSixHundredChars() {
        let bigInput = String(repeating: "a", count: 800)
        let result = SafetyGuard.sanitize(bigInput)
        XCTAssertEqual(result.count, 600)
    }

    func testDisabledReturnsCannedFallback() {
        let context = PlannerContext(
            now: Date(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: false
        )
        XCTAssertTrue(SafetyGuard.shouldShortCircuit(context: context))
    }

    func testEnabledDoesNotShortCircuit() {
        let context = PlannerContext(
            now: Date(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: true
        )
        XCTAssertFalse(SafetyGuard.shouldShortCircuit(context: context))
    }
}
