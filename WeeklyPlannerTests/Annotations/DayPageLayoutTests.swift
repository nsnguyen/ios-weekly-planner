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

    // MARK: - Stack-from-top placement

    func testFirstNoteOnEmptyPageLandsBelowContent() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.stackedAnnotationUnit(contentBottom: 96,
                                                       annotationBottoms: [],
                                                       layerSize: layer)
        // Leading edge on the event column…
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
        // …top edge one stackSpacing below the content column's bottom.
        XCTAssertEqual(unit.y * layer.height, 96 + DayPageLayout.stackSpacing, accuracy: 0.0001)
    }

    func testNoteStacksBelowLowestAnnotation() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.stackedAnnotationUnit(contentBottom: 96,
                                                       annotationBottoms: [180, 320, 240],
                                                       layerSize: layer)
        // The lowest bottom wins — not the last, not the first.
        XCTAssertEqual(unit.y * layer.height, 320 + DayPageLayout.stackSpacing, accuracy: 0.0001)
    }

    func testContentBottomWinsOverNotesDraggedAboveIt() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.stackedAnnotationUnit(contentBottom: 400,
                                                       annotationBottoms: [120, 200],
                                                       layerSize: layer)
        // Notes dragged above the events area don't pull new notes up there.
        XCTAssertEqual(unit.y * layer.height, 400 + DayPageLayout.stackSpacing, accuracy: 0.0001)
    }

    func testAnchorNearPageBottomClampsToHeadroom() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.stackedAnnotationUnit(contentBottom: 96,
                                                       annotationBottoms: [790],
                                                       layerSize: layer)
        // 790 + spacing would run off the page; clamp keeps bottomHeadroom.
        XCTAssertEqual(unit.y * layer.height, 800 - DayPageLayout.bottomHeadroom, accuracy: 0.0001)
    }

    func testDegenerateLayerSizeStaysInUnitRangeForStacking() {
        let unit = DayPageLayout.stackedAnnotationUnit(contentBottom: 96,
                                                       annotationBottoms: [180],
                                                       layerSize: .zero)
        XCTAssertTrue(unit.x.isFinite && unit.x >= 0 && unit.x <= 1)
        XCTAssertTrue(unit.y.isFinite && unit.y >= 0 && unit.y <= 1)
    }
}
