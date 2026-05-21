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
    @Guide(description: "Short human-readable title for the event, or nil if not found.")
    let title: String?
    /// ISO 8601 date-time (Foundation Models returns these as strings).
    @Guide(description: "ISO 8601 start date-time (e.g. 2026-06-12T19:00:00Z), or nil if unknown.")
    let startISO: String?
    @Guide(description: "ISO 8601 end date-time, or nil if unknown.")
    let endISO: String?
    @Guide(description: "Venue or location string, or nil if not mentioned.")
    let location: String?
    /// One of "work", "personal", "health", "social", "errand" — or nil.
    @Guide(description: "One of: work, personal, health, social, errand — or nil.")
    let categoryHint: String?
    /// 0…1; below 0.55 the engine skips upserting an InboxSuggestion.
    @Guide(description: "Confidence from 0 to 1 that this email contains a real event.")
    let confidence: Double
}
#else
struct ExtractedEvent: Codable, Equatable, Sendable {
    let isEvent: Bool
    let title: String?
    /// ISO 8601 date-time (Foundation Models returns these as strings).
    let startISO: String?
    let endISO: String?
    let location: String?
    /// One of "work", "personal", "health", "social", "errand" — or nil.
    let categoryHint: String?
    /// 0…1; below 0.55 the engine skips upserting an InboxSuggestion.
    let confidence: Double
}
#endif
