import XCTest
@testable import WeeklyPlanner

final class AppVersionTests: XCTestCase {
    func testFormatsMarketingAndBuild() {
        XCTAssertEqual(AppVersion.display(marketing: "1.1.0", build: "12"), "v1.1.0 (12)")
    }

    func testFallsBackWhenMissing() {
        XCTAssertEqual(AppVersion.display(marketing: nil, build: nil), "v1.0 (1)")
    }

    func testCurrentReadsTheRealBundle() {
        // The test bundle host app carries the real Info.plist values.
        XCTAssertTrue(AppVersion.current().hasPrefix("v"))
        XCTAssertTrue(AppVersion.current().contains("("))
    }
}
