import XCTest
@testable import WeeklyPlanner

final class TokenKeychainStoreTests: XCTestCase {
    private var serviceID: String!
    private var store: TokenKeychainStore<GoogleAccountInfo>!

    override func setUp() async throws {
        try await super.setUp()
        serviceID = "com.weeklyplanner.tests.\(UUID().uuidString)"
        store = TokenKeychainStore<GoogleAccountInfo>(serviceID: serviceID)
        try store.clear()
    }

    override func tearDown() async throws {
        try? store.clear()
        try await super.tearDown()
    }

    func testSaveAndLoadRoundtrip() throws {
        let info = GoogleAccountInfo(
            email: "sara@gmail.com",
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.save(info)
        let loaded = try store.load()

        XCTAssertEqual(loaded, info)
    }

    func testLoadReturnsNilWhenEmpty() throws {
        let loaded = try store.load()
        XCTAssertNil(loaded)
    }

    func testClearRemovesValue() throws {
        try store.save(.init(email: "x@y.z", accessToken: "a", refreshToken: "r", expiresAt: .init()))
        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testOverwriteReplacesValue() throws {
        let first = GoogleAccountInfo(email: "a@x.com", accessToken: "t1", refreshToken: "r1", expiresAt: .init())
        let second = GoogleAccountInfo(email: "a@x.com", accessToken: "t2", refreshToken: "r2", expiresAt: .init())
        try store.save(first)
        try store.save(second)
        XCTAssertEqual(try store.load(), second)
    }
}
