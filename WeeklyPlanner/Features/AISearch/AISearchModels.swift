import Foundation

/// One pre-baked suggestion the user can tap to fire a query. Mirrors the
/// `AI_SUGGESTIONS` array in `docs/mock/data.jsx`. Phase 13 replaces this
/// static list with on-device Foundation Models output.
struct AISuggestion: Identifiable, Equatable {
    /// Stable identifier — matches the displayed text key. Used for `ForEach`.
    let id: String

    /// Display text shown in the suggestion list (e.g. `"What's on my plate
    /// Friday afternoon?"`).
    let text: String
}

/// A rendered "answer" from the AI overlay. Stubbed in Phase 12 with the
/// handwritten responses from `data.jsx`; Phase 13 replaces it with real
/// Foundation Models output. Fully value-typed so it can flow across
/// `@Observable` boundaries without copy hazards.
struct AIAnswer: Equatable {
    /// The original user query, echoed in the "Q · …" line of State C.
    let query: String

    /// Handwritten answer body — the large blue-ink paragraph below the Q
    /// line.
    let body: String

    /// Resolved Event references shown as yellow citation chips. Pre-resolved
    /// at answer-time so the view layer doesn't re-fetch.
    let citations: [AICitation]

    /// Pill-style quick actions rendered below the answer body.
    let actions: [AIAction]

    /// Wall-clock seconds taken to "answer". Surfaced in the
    /// `"Answered on-device · {x}s"` footer.
    let elapsedSeconds: Double
}

/// A reference to a specific `Event` surfaced as a citation chip beneath an
/// answer. Resolved at answer-time so the view layer can render category dot
/// + title + weekday + time without re-fetching from the store.
struct AICitation: Identifiable, Equatable {
    /// Matches the underlying `Event.id` so tapping the chip can open the
    /// event detail sheet.
    let id: UUID

    /// Event title, displayed in handwriting font on the chip.
    let title: String

    /// Cached category so the chip can render its 6×6 colored dot without a
    /// follow-up fetch.
    let category: Category

    /// Long weekday name (e.g. `"Saturday"`).
    let weekdayLong: String

    /// Short formatted time (e.g. `"8 PM"`).
    let timeShort: String
}

/// A pill-style quick action shown below the answer body. Tapping it is
/// wired by the view layer; the model only carries the label.
struct AIAction: Identifiable, Equatable {
    /// Stable identifier for `ForEach`; routed by the view layer to trigger
    /// the right behavior (e.g. `"directions"` → open Maps).
    let id: String

    /// Display title (e.g. `"Order Uber"`, `"Open inbox"`).
    let title: String
}

/// Canned data sourced from `docs/mock/data.jsx` for Phase 12. Phase 13
/// replaces this with on-device Foundation Models output. All values are
/// `static let`/pure-function so the namespace is `Sendable` by construction.
enum AISearchCannedData {
    /// Pre-baked suggestion chips shown in State A of the overlay. Order
    /// matches the mock's `AI_SUGGESTIONS` array.
    static let suggestions: [AISuggestion] = [
        AISuggestion(id: "friday", text: "What's on my plate Friday afternoon?"),
        AISuggestion(id: "dentist", text: "When's my next dentist appointment?"),
        AISuggestion(id: "freeslot", text: "Find a free 30-min slot tomorrow morning"),
        AISuggestion(id: "inbox", text: "Any unconfirmed events in my inbox?"),
        AISuggestion(id: "sara", text: "When did I last meet with Sara?"),
        AISuggestion(id: "summary", text: "Summarize my week so far"),
    ]

    /// Returns the canned answer body + actions for a given query, plus the
    /// title substrings the view model should use to look up real `Event`
    /// citations.
    ///
    /// The mock's `AI_ANSWERS` references event IDs (`e4`, `e2`, …) that
    /// don't exist in our SwiftData UUID space — so we fall back to
    /// case-insensitive title-substring matching when resolving citations.
    static func canned(for query: String) -> (body: String, actions: [AIAction], titleHints: [String]) {
        let lowercased = query.lowercased()
        if lowercased.contains("dentist") {
            return (body: "Your next dentist appointment is Tuesday at 9:30 AM at 4th Street Dental.",
                    actions: [
                        AIAction(id: "directions", title: "Get directions"),
                        AIAction(id: "remind", title: "Remind me morning of"),
                    ],
                    titleHints: ["dentist"])
        }
        if lowercased.contains("free") || lowercased.contains("slot") {
            return (body: "You have a free 30-min slot tomorrow at 11:00 AM between standup and lunch.",
                    actions: [
                        AIAction(id: "block", title: "Block this slot"),
                        AIAction(id: "later", title: "Show later slots"),
                    ],
                    titleHints: [])
        }
        if lowercased.contains("inbox") || lowercased.contains("email") || lowercased.contains("unconfirmed") {
            return (body: "Three unconfirmed events from Gmail this week. Want me to open them?",
                    actions: [
                        AIAction(id: "open", title: "Open inbox"),
                        AIAction(id: "summarize", title: "Summarize each"),
                    ],
                    titleHints: [])
        }
        if lowercased.contains("sara") {
            return (body: "You last met Sara on Saturday for her birthday breakfast at Marina.",
                    actions: [AIAction(id: "message", title: "Draft a message")],
                    titleHints: ["sara", "birthday"])
        }
        if lowercased.contains("friday") {
            return (body: "Friday afternoon: a pitch deck review at 2 PM and dinner with Mei at 7:30 PM.",
                    actions: [],
                    titleHints: ["pitch", "mei"])
        }
        if lowercased.contains("summarize") || lowercased.contains("summary") {
            return (body: "This week looks balanced — 4 work meetings, 1 fitness session, 2 personal evenings."
                + " Saturday is your busiest day.",
                actions: [AIAction(id: "review", title: "Open review")],
                titleHints: [])
        }
        return (body: "Based on your week, here's what I found.",
                actions: [],
                titleHints: [])
    }
}
