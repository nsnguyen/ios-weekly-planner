import Foundation

/// What the Foundation Models extractor returns for a single Gmail message.
/// All fields except `isEvent` and `confidence` are optional — the extractor
/// must not invent missing data.
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
