import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventExtractorTests: XCTestCase {

    // MARK: - StubEventExtractor

    func testStubExtractorAlwaysReturnsFalse() async throws {
        let sut = StubEventExtractor()
        let result = try await sut.extract(
            subject: "Your reservation at Café Bleu",
            snippet: "Friday 7pm",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            body: "Reservation confirmed for Friday at 7pm"
        )
        XCTAssertFalse(result.isEvent)
        XCTAssertEqual(result.confidence, 0)
    }

    // MARK: - Fake extractor (exercises the protocol surface that InboxSyncEngine consumes)

    func testFakeResyConfirmationExtractsTitleAndStart() async throws {
        let fake = FakeEventExtractor()
        fake.nextResult = ExtractedEvent(
            isEvent: true,
            title: "Dinner at Café Bleu",
            startISO: "2026-06-12T19:00:00Z",
            endISO: "",
            location: "Café Bleu",
            categoryHint: "social",
            confidence: 0.92
        )

        let result = try await fake.extract(
            subject: "Reservation confirmed",
            snippet: "Friday 7pm",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            body: "..."
        )

        XCTAssertTrue(result.isEvent)
        XCTAssertEqual(result.title, "Dinner at Café Bleu")
        XCTAssertEqual(result.startISO, "2026-06-12T19:00:00Z")
        XCTAssertEqual(result.location, "Café Bleu")
        XCTAssertEqual(fake.callCount, 1)
    }

    func testFakeAmbiguousEmailReturnsIsEventFalse() async throws {
        let fake = FakeEventExtractor()
        fake.nextResult = ExtractedEvent(
            isEvent: false, title: "", startISO: "", endISO: "",
            location: "", categoryHint: "", confidence: 0.2
        )

        let result = try await fake.extract(
            subject: "Update from the team",
            snippet: "...", fromName: "Co-Worker", fromEmail: "x@y.com", body: "..."
        )

        XCTAssertFalse(result.isEvent)
    }

    func testFakeMissingTimeReturnsEmptyStart() async throws {
        let fake = FakeEventExtractor()
        fake.nextResult = ExtractedEvent(
            isEvent: true, title: "Meeting", startISO: "", endISO: "",
            location: "", categoryHint: "work", confidence: 0.6
        )

        let result = try await fake.extract(subject: "", snippet: "", fromName: "", fromEmail: "", body: "")

        XCTAssertTrue(result.isEvent)
        XCTAssertEqual(result.startISO, "")
    }
}

// MARK: - Test double

@MainActor
final class FakeEventExtractor: EventExtractor {
    var nextResult: ExtractedEvent = ExtractedEvent(
        isEvent: false, title: "", startISO: "", endISO: "",
        location: "", categoryHint: "", confidence: 0
    )
    var nextError: Error?
    private(set) var callCount = 0
    private(set) var lastSubject: String?

    nonisolated init() {}

    func extract(
        subject: String,
        snippet _: String,
        fromName _: String,
        fromEmail _: String,
        body _: String
    ) async throws -> ExtractedEvent {
        callCount += 1
        lastSubject = subject
        if let error = nextError { throw error }
        return nextResult
    }
}
