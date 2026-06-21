import XCTest
@testable import WeeklyPlanner

/// `OneShotResult` is the cancellation-safety core of the GIDSignIn
/// callback→continuation bridge: the SDK callback and task cancellation both
/// call `deliver`, and exactly one must win (resuming the continuation once),
/// regardless of whether the sink was registered before or after delivery.
final class OneShotResultTests: XCTestCase {
    func testOnReadyThenDeliverForwardsResultOnce() {
        let oneShot = OneShotResult<Int, Error>()
        var received: [Result<Int, Error>] = []
        oneShot.onReady { received.append($0) }
        oneShot.deliver(.success(42))
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(try? received.first?.get(), 42)
    }

    func testDeliverThenOnReadyDeliversStashedResult() {
        // Cancellation can arrive BEFORE the continuation is registered; the
        // result must still reach the sink once it registers.
        let oneShot = OneShotResult<Int, Error>()
        var received: [Result<Int, Error>] = []
        oneShot.deliver(.success(7))
        oneShot.onReady { received.append($0) }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(try? received.first?.get(), 7)
    }

    func testSecondDeliverIsIgnoredAfterOnReady() {
        let oneShot = OneShotResult<Int, Error>()
        var received: [Result<Int, Error>] = []
        oneShot.onReady { received.append($0) }
        oneShot.deliver(.success(1))
        oneShot.deliver(.success(2)) // e.g. SDK callback firing after cancellation
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(try? received.first?.get(), 1)
    }

    func testFirstDeliverWinsEvenBeforeOnReady() {
        let oneShot = OneShotResult<Int, Error>()
        var received: [Result<Int, Error>] = []
        oneShot.deliver(.success(1)) // cancellation
        oneShot.deliver(.success(2)) // late SDK callback — must be ignored
        oneShot.onReady { received.append($0) }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(try? received.first?.get(), 1)
    }

    func testDeliverFailurePropagates() {
        let oneShot = OneShotResult<Int, Error>()
        var received: [Result<Int, Error>] = []
        oneShot.onReady { received.append($0) }
        oneShot.deliver(.failure(CancellationError()))
        XCTAssertEqual(received.count, 1)
        guard case .failure(let error)? = received.first else { return XCTFail("expected failure") }
        XCTAssertTrue(error is CancellationError)
    }
}
