import CoreGraphics
import Foundation
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

    // MARK: - Auto-nudge on content growth

    private func note(_ id: UUID, unitY: Double, autoPlaced: Bool = true)
        -> (id: UUID, unitY: Double, autoPlaced: Bool)
    {
        (id: id, unitY: unitY, autoPlaced: autoPlaced)
    }

    func testNoCollisionsYieldsNoNudges() {
        let id = UUID()
        // Note top (0.5 × 800 = 400) is below the content bottom (200).
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.5)], editingID: nil, contentBottom: 200,
            noteHeights: [id: 20], layerSize: CGSize(width: 400, height: 800))
        XCTAssertTrue(nudges.isEmpty)
    }

    func testPinnedCollidingNoteIsNotNudged() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1, autoPlaced: false)], editingID: nil,
            contentBottom: 200, noteHeights: [id: 20],
            layerSize: CGSize(width: 400, height: 800))
        XCTAssertTrue(nudges.isEmpty)
    }

    func testEditingNoteIsNotNudged() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1)], editingID: id, contentBottom: 200,
            noteHeights: [id: 20], layerSize: CGSize(width: 400, height: 800))
        XCTAssertTrue(nudges.isEmpty)
    }

    func testCollidingNoteRestacksBelowContent() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1)], editingID: nil, contentBottom: 200,
            noteHeights: [id: 20], layerSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(nudges.map(\.id), [id])
        XCTAssertEqual(nudges[0].unitY * 800, 200 + DayPageLayout.stackSpacing, accuracy: 0.0001)
    }

    func testMultipleCollidingNotesRestackInVerticalOrder() {
        let a = UUID(), b = UUID()
        // Passed b-first to prove ordering comes from unitY, not input order.
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(b, unitY: 0.15), note(a, unitY: 0.05)], editingID: nil,
            contentBottom: 200, noteHeights: [a: 20, b: 20],
            layerSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(nudges.map(\.id), [a, b])
        XCTAssertEqual(nudges[0].unitY * 800, 212, accuracy: 0.0001) // 200 + 12
        XCTAssertEqual(nudges[1].unitY * 800, 244, accuracy: 0.0001) // 212 + 20 + 12
    }

    func testNudgedNoteLandsBelowPinnedNoteUnderTheContent() {
        let moving = UUID(), pinned = UUID()
        // Pinned note sits below the content (top 320, bottom 340) — the
        // nudged note must clear it, not just the content bottom.
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(moving, unitY: 0.1), note(pinned, unitY: 0.4, autoPlaced: false)],
            editingID: nil, contentBottom: 200,
            noteHeights: [moving: 20, pinned: 20],
            layerSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(nudges.map(\.id), [moving])
        XCTAssertEqual(nudges[0].unitY * 800, 340 + DayPageLayout.stackSpacing, accuracy: 0.0001)
    }

    func testDegenerateLayerYieldsNoNudges() {
        let id = UUID()
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.1)], editingID: nil, contentBottom: 200,
            noteHeights: [id: 20], layerSize: .zero)
        XCTAssertTrue(nudges.isEmpty)
    }
}
