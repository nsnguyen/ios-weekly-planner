import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What the Foundation Models extractor returns for a single Gmail message.
/// All fields except `isEvent` and `confidence` are optional — the extractor
/// must not invent missing data.
///
/// `@Generable` (iOS 26+) enables structured-output mode in
/// `LanguageModelSession.respond(to:generating:)`. The macro is gated
/// `#if canImport(FoundationModels)` so the type compiles cleanly on older
/// simulators and in test targets that don't link the framework.
#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct ExtractedEvent: Codable, Equatable, Sendable {
    @Guide(description: "True if the email announces a calendar event, reservation, or appointment.")
    let isEvent: Bool
    /// REQUIRED when isEvent=true. Use empty string "" when isEvent=false.
    @Guide(description: "Short event title taken from the email subject or body. Always provide this when isEvent=true. Use empty string only when isEvent=false.")
    let title: String
    /// REQUIRED when isEvent=true. ISO 8601 with timezone offset. Use empty
    /// string "" when isEvent=false.
    @Guide(description: "Event start in ISO 8601 with timezone, e.g. '2026-05-23T19:00:00-07:00'. Always provide this when isEvent=true. Use empty string only when isEvent=false.")
    let startISO: String
    @Guide(description: "ISO 8601 end date-time. Empty string if the email doesn't state an end time.")
    let endISO: String
    @Guide(description: "Venue or location from the email body. Empty string if not mentioned.")
    let location: String
    @Guide(description: "One of: work, personal, health, social, errand. Empty string if unclear.")
    let categoryHint: String
    @Guide(description: "Confidence from 0 to 1 that this email describes a real upcoming event.")
    let confidence: Double
}
#else
struct ExtractedEvent: Codable, Equatable, Sendable {
    let isEvent: Bool
    /// REQUIRED when isEvent=true. Empty string when isEvent=false.
    let title: String
    /// REQUIRED when isEvent=true. ISO 8601 with timezone. Empty when isEvent=false.
    let startISO: String
    let endISO: String
    let location: String
    let categoryHint: String
    /// 0…1; below 0.55 the engine skips upserting an InboxSuggestion.
    let confidence: Double
}
#endif
