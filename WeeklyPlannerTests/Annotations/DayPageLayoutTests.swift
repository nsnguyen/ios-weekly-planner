import CoreGraphics
import XCTest
@testable import WeeklyPlanner

final class DayPageLayoutTests: XCTestCase {

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

    func testLayerShorterThanHeadroomFloorsAtPageTop() {
        // Unreachable in production (the layer is floored to the viewport
        // height), but pins the clamp-order behavior: a sub-headroom layer
        // yields a negative target y, floored to the page top by clampUnit.
        let unit = DayPageLayout.stackedAnnotationUnit(contentBottom: 30,
                                                       annotationBottoms: [],
                                                       layerSize: CGSize(width: 400, height: 40))
        XCTAssertEqual(unit.y, 0, accuracy: 0.0001)
    }

    func testDegenerateLayerSizeStaysInUnitRangeForStacking() {
        let unit = DayPageLayout.stackedAnnotationUnit(contentBottom: 96,
                                                       annotationBottoms: [180],
                                                       layerSize: .zero)
        XCTAssertTrue(unit.x.isFinite && unit.x >= 0 && unit.x <= 1)
        XCTAssertTrue(unit.y.isFinite && unit.y >= 0 && unit.y <= 1)
    }
}
