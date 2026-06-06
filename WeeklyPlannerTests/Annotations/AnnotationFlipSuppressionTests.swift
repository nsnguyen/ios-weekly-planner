import XCTest
@testable import WeeklyPlanner

@MainActor
final class AnnotationFlipSuppressionTests: XCTestCase {
    func testAnnotationDragFlagDefaultsToFalseAndIsIndependentOfStickyFlag() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 0))
        XCTAssertFalse(controller.annotationDragActive)

        controller.annotationDragActive = true
        XCTAssertFalse(controller.stickyDragActive,
                       "Annotation drags must not piggyback on the sticky flag — independent suppressors")
        controller.annotationDragActive = false
        XCTAssertFalse(controller.annotationDragActive)
    }
}
