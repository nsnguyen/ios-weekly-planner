import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AnnotationStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataAnnotationStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataAnnotationStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testRoundTripPreservesStyleAndPosition() async throws {
        let a = Annotation(dayKey: "0:5", text: "call mom",
                           colorToken: .red, isBold: true,
                           unitX: 0.62, unitY: 0.31)
        try await store.upsert(a)

        let fetched = try await store.annotations(dayKey: "0:5")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "call mom")
        XCTAssertEqual(fetched.first?.colorToken, .red)
        XCTAssertEqual(fetched.first?.isBold, true)
        XCTAssertEqual(fetched.first?.unitX ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(fetched.first?.unitY ?? 0, 0.31, accuracy: 0.0001)
    }

    func testAnnotationsAreScopedToTheirDayKey() async throws {
        try await store.upsert(Annotation(dayKey: "0:5", text: "sat", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))
        try await store.upsert(Annotation(dayKey: "0:4", text: "fri", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))

        let saturday = try await store.annotations(dayKey: "0:5")
        XCTAssertEqual(saturday.map(\.text), ["sat"])
    }

    func testUpsertExistingUpdatesInPlace() async throws {
        let id = UUID()
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v1", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v2", colorToken: .green, isBold: true, unitX: 0.1, unitY: 0.9))

        let count = try container.mainContext.fetch(FetchDescriptor<Annotation>()).count
        XCTAssertEqual(count, 1, "Upsert should update, not insert a second row")
        let fetched = try await store.annotations(dayKey: "0:5").first
        XCTAssertEqual(fetched?.text, "v2")
        XCTAssertEqual(fetched?.colorToken, .green)
    }

    func testDeleteRemovesAnnotation() async throws {
        let a = Annotation(dayKey: "0:5", text: "bye", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5)
        try await store.upsert(a)
        try await store.delete(id: a.id)
        let remaining = try await store.annotations(dayKey: "0:5")
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMutationsPostChangeNotification() async throws {
        let exp = expectation(forNotification: .annotationStoreDidChange, object: nil)
        try await store.upsert(Annotation(dayKey: "0:5", text: "ping", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5))
        await fulfillment(of: [exp], timeout: 1)
    }

    func testClampUnitBoundsToUnitSquare() {
        let clamped = Annotation.clampUnit(CGPoint(x: 1.4, y: -0.2))
        XCTAssertEqual(clamped.x, 1.0)
        XCTAssertEqual(clamped.y, 0.0)

        let recovered = Annotation.clampUnit(CGPoint(x: CGFloat.nan, y: .infinity))
        XCTAssertEqual(recovered.x, 0.5, "Non-finite coordinates must recover to center, not persist")
        XCTAssertEqual(recovered.y, 0.5)
    }

    func testDeletePostsChangeNotification() async throws {
        let a = Annotation(dayKey: "0:5", text: "x", colorToken: .ink, isBold: false, unitX: 0.5, unitY: 0.5)
        try await store.upsert(a)
        let exp = expectation(forNotification: .annotationStoreDidChange, object: nil)
        try await store.delete(id: a.id)
        await fulfillment(of: [exp], timeout: 1)
    }

    func testAnnotationsReturnedOldestFirst() async throws {
        let early = Annotation(dayKey: "0:5", text: "first",
                               colorToken: .ink, isBold: false, unitX: 0.1, unitY: 0.1,
                               createdAt: Date(timeIntervalSinceReferenceDate: 1000),
                               updatedAt: Date(timeIntervalSinceReferenceDate: 1000))
        let late = Annotation(dayKey: "0:5", text: "second",
                              colorToken: .ink, isBold: false, unitX: 0.2, unitY: 0.2,
                              createdAt: Date(timeIntervalSinceReferenceDate: 2000),
                              updatedAt: Date(timeIntervalSinceReferenceDate: 2000))
        try await store.upsert(late)
        try await store.upsert(early)
        let result = try await store.annotations(dayKey: "0:5")
        XCTAssertEqual(result.map(\.text), ["first", "second"], "Promised oldest-first z-order")
    }

    func testDayKeyHelperMatchesAppScheme() {
        XCTAssertEqual(Annotation.key(weekOffset: 0, dayIdx: 5), "0:5")
        XCTAssertEqual(Annotation.key(weekOffset: -2, dayIdx: 0), "-2:0")
    }

    func testAutoPlacedFlagRoundTrips() async throws {
        let a = Annotation(dayKey: "0:5", text: "stacked", colorToken: .ink,
                           isBold: false, autoPlaced: true, unitX: 0.1, unitY: 0.2)
        try await store.upsert(a)

        let fetched = try await store.annotations(dayKey: "0:5").first
        XCTAssertEqual(fetched?.autoPlaced, true)
    }

    func testUpsertExistingUpdatesAutoPlaced() async throws {
        let id = UUID()
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v1", colorToken: .ink,
                                          isBold: false, autoPlaced: true, unitX: 0.5, unitY: 0.5))
        // Drag-commit path writes the same row with the flag cleared — the
        // store's field-by-field update copy must include it.
        try await store.upsert(Annotation(id: id, dayKey: "0:5", text: "v1", colorToken: .ink,
                                          isBold: false, autoPlaced: false, unitX: 0.5, unitY: 0.6))

        let fetched = try await store.annotations(dayKey: "0:5").first
        XCTAssertEqual(fetched?.autoPlaced, false)
    }
}
