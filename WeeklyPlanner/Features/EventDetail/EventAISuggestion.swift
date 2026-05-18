import Foundation

/// Canned AI-suggestion copy for the yellow sticky inside the event detail
/// sheet. Phase 13 replaces this stub with Foundation Models output; for now
/// we ship hand-authored strings keyed off title substrings so the seed
/// events (`e17`, `e4`, …) still match after their IDs are remapped to
/// SwiftData UUIDs during seeding.
enum EventAISuggestion {
    /// Returns the suggestion text for a given event. The match is performed
    /// on a lowercased copy of `event.title` so casing in the source data
    /// doesn't change the result.
    static func text(for event: Event) -> String {
        let lower = event.title.lowercased()
        if lower.contains("birthday") {
            return "Order an Uber at 7:35 PM. Trick Dog is a 22-min drive Saturday night."
        }
        if lower.contains("sara") {
            return "You haven't replied to Sara about Saturday. Want me to draft a quick message?"
        }
        if lower.contains("dentist") {
            return "Tuesday morning has light traffic to 4th Street. Leaving by 9:35 should work."
        }
        return "Block 15 min of focus time before this so you're not rushing in."
    }
}
