import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Foundation Models-backed `EventExtractor`. Uses `LanguageModelSession`'s
/// structured-output mode (`respond(to:generating:)`) to return an
/// `ExtractedEvent` directly without any string parsing. Gated to iOS 26+
/// via `#if canImport(FoundationModels)` and `@available`.
///
/// The system prompt explicitly forbids inventing missing fields:
/// startISO/endISO/location must remain nil when not stated in the email.
/// Confidence below 0.55 is the engine's signal to skip the suggestion.
@MainActor
final class LiveEventExtractor: EventExtractor {
    nonisolated init() {}

    func extract(
        subject: String,
        snippet: String,
        fromName: String,
        fromEmail: String,
        body: String
    ) async throws -> ExtractedEvent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await extractWithFoundationModels(
                subject: subject,
                snippet: snippet,
                fromName: fromName,
                fromEmail: fromEmail,
                body: body
            )
        }
        #endif
        return ExtractedEvent(
            isEvent: false, title: nil, startISO: nil, endISO: nil,
            location: nil, categoryHint: nil, confidence: 0
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func extractWithFoundationModels(
        subject: String,
        snippet: String,
        fromName: String,
        fromEmail: String,
        body: String
    ) async throws -> ExtractedEvent {
        let session = LanguageModelSession(instructions: Self.systemPrompt)
        let prompt = """
        From the email below, extract a single calendar event.
        If no event is present, set isEvent=false and leave other fields null.
        Never invent details: if a field is not in the email, leave it null.

        From: \(fromName) <\(fromEmail)>
        Subject: \(subject)
        Snippet: \(snippet)
        Body:
        \(body)
        """
        let response = try await session.respond(to: prompt, generating: ExtractedEvent.self)
        return response.content
    }

    private static let systemPrompt = """
    You are an event extractor for a calendar app. Given an email, return
    structured JSON describing the event it announces. Set isEvent=false
    if the email is not an invitation, confirmation, or reservation.
    All time fields use ISO 8601. Never fabricate missing data — leave
    fields null rather than guessing.
    """
    #endif
}
