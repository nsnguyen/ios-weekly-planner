import Foundation

/// Produces the one-line AI suggestion that fills the yellow sticky inside
/// the event detail sheet. Wraps an `IntelligenceService` with an
/// event-specific prompt so the rest of the view-model code just calls
/// `generate(for:)` and gets a string back.
///
/// Returns `nil` whenever the model is unavailable or errors out — the
/// caller is expected to fall back to the canned `EventAISuggestion`
/// table in that case, so the user still sees a sticky with useful copy.
@MainActor
final class EventSuggestionGenerator {
    private let intelligence: any IntelligenceService
    private let settings: () -> Bool
    private let clock: () -> Date

    init(intelligence: any IntelligenceService,
         settings: @escaping () -> Bool = { true },
         clock: @escaping () -> Date = { Date() })
    {
        self.intelligence = intelligence
        self.settings = settings
        self.clock = clock
    }

    /// Generates a one-sentence AI suggestion for the given event.
    /// Returns `nil` if the model isn't available or refuses, so the
    /// caller can fall back to its canned-text path without surfacing
    /// an error to the user.
    func generate(for event: Event) async -> String? {
        let context = PlannerContext(
            now: clock(),
            viewedWeekOffset: 0,
            maxResponseTokens: 120,
            appleIntelligenceEnabled: settings()
        )
        let availability = await intelligence.availability(context: context)
        guard availability.isAvailable else { return nil }

        let prompt = Self.prompt(for: event)
        do {
            let answer = try await intelligence.ask(query: prompt, context: context)
            let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    /// Pure prompt builder. Exposed for tests so the prompt shape stays
    /// stable across edits.
    static func prompt(for event: Event) -> String {
        let title = event.title
        let category = (Category(rawValue: event.categoryRaw) ?? .personal).rawValue
        let when = Self.dateFormatter.string(from: event.start)
        var lines = [
            "Write one short, actionable suggestion (≤ 140 chars, no emoji) for the user about this event:",
            "Title: \(title)",
            "When: \(when)",
            "Category: \(category)",
        ]
        if let location = event.location, !location.isEmpty {
            lines.append("Location: \(location)")
        }
        if event.attendeesCount > 1 {
            lines.append("Attendees: \(event.attendeesCount)")
        }
        if let travel = event.travelMinutes {
            lines.append("Travel time: \(travel) minutes")
        }
        lines.append("Reply with just the suggestion sentence — no preamble.")
        return lines.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE 'at' h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
