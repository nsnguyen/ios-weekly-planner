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

    func testCollidingNoteNearPageBottomClampsToHeadroom() {
        let id = UUID()
        // contentBottom deep in the page: target = min(760 + 12, 740) = 740.
        let nudges = DayPageLayout.nudgesForContentGrowth(
            notes: [note(id, unitY: 0.5)], editingID: nil, contentBottom: 760,
            noteHeights: [id: 20], layerSize: CGSize(width: 400, height: 800))
        XCTAssertEqual(nudges.map(\.id), [id])
        XCTAssertEqual(nudges[0].unitY * 800, 800 - DayPageLayout.bottomHeadroom, accuracy: 0.0001)
    }

    func testReapplyingPlanYieldsNoFurtherNudges() {
        let a = UUID(), b = UUID()
        let layer = CGSize(width: 400, height: 800)
        let heights: [UUID: CGFloat] = [a: 20, b: 20]
        // Content fills past the headroom line: both notes pile at the clamp.
        let first = DayPageLayout.nudgesForContentGrowth(
            notes: [note(a, unitY: 0.05), note(b, unitY: 0.15)],
            editingID: nil, contentBottom: 750, noteHeights: heights, layerSize: layer)
        XCTAssertEqual(first.count, 2, "both notes should move down to the clamp")

        // Apply the plan, then re-run at the same contentBottom: a settled
        // page must emit nothing — no perpetual no-op nudges (each would
        // become a pointless SwiftData write at the call site).
        var moved: [UUID: Double] = [a: 0.05, b: 0.15]
        for nudge in first { moved[nudge.id] = nudge.unitY }
        let second = DayPageLayout.nudgesForContentGrowth(
            notes: [note(a, unitY: moved[a]!), note(b, unitY: moved[b]!)],
            editingID: nil, contentBottom: 750, noteHeights: heights, layerSize: layer)
        XCTAssertTrue(second.isEmpty)
    }

    // MARK: - Vertical-only drag destination

    func testVerticalDragKeepsLeadingEdgeOnTheMargin() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.5,
                                                  translationHeight: 0,
                                                  layerSize: layer)
        // X always lands on the page margin — the helper takes no starting X.
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
        XCTAssertEqual(unit.y, 0.5, accuracy: 0.0001)
    }

    func testVerticalDragMovesYByTranslationOnly() {
        let layer = CGSize(width: 400, height: 800)
        // Start at 400pt (0.5), drag down 80pt → 480pt; X stays on the margin.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.5,
                                                  translationHeight: 80,
                                                  layerSize: layer)
        XCTAssertEqual(unit.y * layer.height, 480, accuracy: 0.0001)
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testVerticalDragUpwardClampsAtPageTop() {
        let layer = CGSize(width: 400, height: 800)
        // From 80pt (0.1), drag up 200pt → −120pt, floored to the top.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.1,
                                                  translationHeight: -200,
                                                  layerSize: layer)
        XCTAssertEqual(unit.y, 0, accuracy: 0.0001)
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testVerticalDragDownwardClampsAtPageBottom() {
        let layer = CGSize(width: 400, height: 800)
        // From 720pt (0.9), drag down 200pt → 920pt (1.15), clamped to 1.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.9,
                                                  translationHeight: 200,
                                                  layerSize: layer)
        XCTAssertEqual(unit.y, 1, accuracy: 0.0001)
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testVerticalDragDegenerateLayerStaysInUnitRange() {
        // Guarded out in the gesture, but the helper must stay finite on a
        // zero layer — mirrors testDegenerateLayerSizeStaysInUnitRangeForStacking.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.5,
                                                  translationHeight: 40,
                                                  layerSize: .zero)
        XCTAssertTrue(unit.x.isFinite && unit.x >= 0 && unit.x <= 1)
        XCTAssertTrue(unit.y.isFinite && unit.y >= 0 && unit.y <= 1)
    }

    // MARK: - Compact-reorder stack

    func testCompactPacksTwoNotesTightBelowContent() {
        let a = UUID(), b = UUID()
        let layer = CGSize(width: 400, height: 800)
        let placements = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.3, height: 20), (id: b, unitY: 0.6, height: 20)],
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(placements.map(\.id), [a, b])
        XCTAssertEqual(placements[0].unitY * 800, 112, accuracy: 0.0001) // 100 + stackSpacing(12)
        XCTAssertEqual(placements[1].unitY * 800, 144, accuracy: 0.0001) // 112 + 20 + 12
    }

    func testCompactIsIdempotent() {
        let a = UUID(), b = UUID()
        let layer = CGSize(width: 400, height: 800)
        let first = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.3, height: 20), (id: b, unitY: 0.6, height: 20)],
            contentBottom: 100, layerSize: layer)
        let second = DayPageLayout.compactedStack(
            notes: first.map { (id: $0.id, unitY: $0.unitY, height: CGFloat(20)) },
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(first, second)
    }

    func testCompactOrdersByUnitYNotInputOrder() {
        let a = UUID(), b = UUID(), c = UUID()
        let layer = CGSize(width: 400, height: 800)
        // Input order b, a, c; unitY says a(0.1) < c(0.5) < b(0.9) → packed a, c, b.
        let placements = DayPageLayout.compactedStack(
            notes: [(id: b, unitY: 0.9, height: 20),
                    (id: a, unitY: 0.1, height: 20),
                    (id: c, unitY: 0.5, height: 20)],
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(placements.map(\.id), [a, c, b])
    }

    func testCompactReordersNoteDroppedBetweenTwo() {
        let a = UUID(), b = UUID(), moved = UUID()
        let layer = CGSize(width: 400, height: 800)
        // a(0.14), b(0.18); `moved` dropped at 0.16 (between) → a, moved, b.
        let placements = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.14, height: 20),
                    (id: b, unitY: 0.18, height: 20),
                    (id: moved, unitY: 0.16, height: 20)],
            contentBottom: 100, layerSize: layer)
        XCTAssertEqual(placements.map(\.id), [a, moved, b])
    }

    func testCompactClampsTallStackAtPageBottom() {
        let a = UUID(), b = UUID()
        let layer = CGSize(width: 400, height: 800)
        // contentBottom deep: both clamp at 800 - bottomHeadroom(60) = 740.
        let placements = DayPageLayout.compactedStack(
            notes: [(id: a, unitY: 0.95, height: 20), (id: b, unitY: 0.97, height: 20)],
            contentBottom: 760, layerSize: layer)
        XCTAssertEqual(placements[0].unitY * 800, 740, accuracy: 0.0001)
        XCTAssertEqual(placements[1].unitY * 800, 740, accuracy: 0.0001)
    }

    func testCompactDegenerateLayerReturnsEmpty() {
        XCTAssertTrue(DayPageLayout.compactedStack(
            notes: [(id: UUID(), unitY: 0.5, height: 20)],
            contentBottom: 100, layerSize: .zero).isEmpty)
    }
}
