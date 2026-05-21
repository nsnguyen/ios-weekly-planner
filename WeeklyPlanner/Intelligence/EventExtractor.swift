import Foundation

/// One-call extractor: takes a Gmail message's text fields, returns a
/// structured `ExtractedEvent`. Production: `LiveEventExtractor`
/// (Foundation Models, iOS 26+). Tests + BG-fallback: `StubEventExtractor`.
@MainActor
protocol EventExtractor: AnyObject {
    func extract(
        subject: String,
        snippet: String,
        fromName: String,
        fromEmail: String,
        body: String
    ) async throws -> ExtractedEvent
}

/// Always returns `isEvent: false`. Used by:
/// - Unit tests that don't want to exercise the model.
/// - The runtime fallback when Foundation Models is unavailable
///   (older device, Apple Intelligence off, background context).
@MainActor
final class StubEventExtractor: EventExtractor {
    nonisolated init() {}

    func extract(
        subject _: String,
        snippet _: String,
        fromName _: String,
        fromEmail _: String,
        body _: String
    ) async throws -> ExtractedEvent {
        ExtractedEvent(
            isEvent: false,
            title: nil,
            startISO: nil,
            endISO: nil,
            location: nil,
            categoryHint: nil,
            confidence: 0
        )
    }
}
