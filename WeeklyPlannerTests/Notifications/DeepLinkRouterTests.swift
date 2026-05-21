import XCTest
@testable import WeeklyPlanner

@MainActor
final class DeepLinkRouterTests: XCTestCase {

    func testRequestEventStoresUUID() {
        let router = DeepLinkRouter()
        let id = UUID()
        router.request(.event(id))
        XCTAssertEqual(router.pending, .event(id))
    }

    func testConsumeReturnsAndClears() {
        let router = DeepLinkRouter()
        let id = UUID()
        router.request(.task(id))
        let consumed = router.consume()
        XCTAssertEqual(consumed, .task(id))
        XCTAssertNil(router.pending)
    }
}
