import SwiftUI
import XCTest
@testable import WeeklyPlanner

final class TornEdgeShapeTests: XCTestCase {
    func testPathTileWidthHeightConstants() {
        XCTAssertEqual(TornEdgeShape.tileWidth, 40)
        XCTAssertEqual(TornEdgeShape.tileHeight, 10)
    }

    func testPathContainsExpectedTopEdgeVerticesAtTileZero() {
        let shape = TornEdgeShape()
        let rect = CGRect(x: 0, y: 0, width: 40, height: 100)
        let path = shape.path(in: rect)

        // The zigzag's topmost peak sits at y = 2 (the `L15 2` vertex), so the
        // bounding rect runs from y = 2 down to y = 100 — width fills the rect,
        // and the bottom of the path lines up with `rect.maxY`.
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.boundingRect.width, 40, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.maxY, 100, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.minY, 2, accuracy: 0.001)
    }

    func testPathTilesAcrossMultipleWidths() {
        let shape = TornEdgeShape()
        let rect = CGRect(x: 0, y: 0, width: 120, height: 100)
        let path = shape.path(in: rect)

        // Three tiles laid end to end fill the 120pt width exactly; the
        // bottom of the path lines up with `rect.maxY` so callers can use it
        // as a clip shape that bottoms out against the surrounding container.
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.boundingRect.width, 120, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.maxY, 100, accuracy: 0.001)
    }
}
