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
            isEvent: false, title: "", startISO: "", endISO: "",
            location: "", categoryHint: "", confidence: 0
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
        Extract a single calendar event from the email below.

        Decision rules:
        - Set isEvent=true ONLY if the email announces a specific event with a
          date/time (invitation, confirmation, reservation, appointment, ticket).
        - When isEvent=true, you MUST populate title and startISO with the
          values you find in the email body. These fields are required — do
          not leave them null when isEvent=true.
        - title: a short human-readable name for the event (e.g. "Dinner at
          Café Bleu", "Dr. Smith appointment").
        - startISO: the event start in ISO 8601 with timezone, e.g.
          "2026-05-23T19:00:00-07:00" or "2026-05-23T19:00:00Z". Resolve the
          date and time precisely from the email body — pick the explicit
          date if one is given.
        - endISO, location, categoryHint: populate when explicitly stated;
          otherwise leave null. These are the only truly optional fields.
        - confidence: 0…1, your confidence that this is a real event.

        If isEvent=false, leave all other fields null.

        Email:
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
    You are an event extractor for a calendar app. You read emails and
    return structured JSON describing the calendar event they announce.
    When the email IS an event (invitation, confirmation, reservation,
    appointment, ticket), you always populate title and startISO with the
    values present in the email — those two fields are required whenever
    isEvent=true. endISO, location, and categoryHint may be null when the
    email doesn't state them. All time fields use ISO 8601.
    """
    #endif
}
