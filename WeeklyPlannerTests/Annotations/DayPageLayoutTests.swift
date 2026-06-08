import CoreGraphics
import XCTest
@testable import WeeklyPlanner

final class DayPageLayoutTests: XCTestCase {

    func testNewAnnotationLeadingEdgeLandsOnPageMargin() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.annotationCreationUnit(pressY: 300, layerSize: layer)

        // Leading edge sits exactly on the event column (the page margin)…
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
        // …and the vertical position is preserved at the press point.
        XCTAssertEqual(unit.y * layer.height, 300, accuracy: 0.0001)
    }

    func testHorizontalPressIsIrrelevantToColumn() {
        // The helper takes no press-X by design; the column is constant
        // regardless of layer width, so two widths still map x back to margin.
        let narrow = DayPageLayout.annotationCreationUnit(pressY: 100, layerSize: CGSize(width: 320, height: 600))
        let wide = DayPageLayout.annotationCreationUnit(pressY: 100, layerSize: CGSize(width: 800, height: 600))

        XCTAssertEqual(narrow.x * 320, DayPageLayout.pageMargin, accuracy: 0.0001)
        XCTAssertEqual(wide.x * 800, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testDegenerateLayerSizeStaysInUnitRange() {
        let unit = DayPageLayout.annotationCreationUnit(pressY: 120, layerSize: .zero)

        XCTAssertTrue(unit.x.isFinite && unit.x >= 0 && unit.x <= 1)
        XCTAssertTrue(unit.y.isFinite && unit.y >= 0 && unit.y <= 1)
    }
}
