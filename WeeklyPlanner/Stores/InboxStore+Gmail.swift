import Foundation

/// Phase 18 helper: build an `InboxSuggestion` from the engine's pipeline
/// outputs. Kept here so `InboxSyncEngine.upsert(...)` reads naturally
/// without inlining all the field mapping.
extension InboxSuggestion {
    static func fromExtractedEvent(
        _ extracted: ExtractedEvent,
        message: GmailMessage,
        fallbackCategory: Category = .personal
    ) -> InboxSuggestion? {
        guard extracted.isEvent,
              let title = extracted.title,
              let startISO = extracted.startISO,
              let start = ISO8601DateFormatter().date(from: startISO)
        else { return nil }

        let end = extracted.endISO.flatMap { ISO8601DateFormatter().date(from: $0) }
        let category = Category(rawValue: extracted.categoryHint ?? "") ?? fallbackCategory
        let fromHeader = message.header("From") ?? ""
        let (fromName, fromEmail) = parseFromHeader(fromHeader)

        return InboxSuggestion(
            gmailMessageID: message.id,
            proposedStart: start,
            proposedEnd: end,
            title: title,
            fromName: fromName,
            fromEmail: fromEmail,
            category: category,
            subject: message.header("Subject") ?? "",
            bodySnippet: message.snippet,
            proposedLocation: extracted.location
        )
    }

    /// Splits an RFC-822 From header ("Display Name <user@example.com>")
    /// into name + email. Falls back to ("", fullValue) when there's no
    /// angle-bracketed email.
    private static func parseFromHeader(_ value: String) -> (name: String, email: String) {
        guard let openBracket = value.firstIndex(of: "<"),
              let closeBracket = value.firstIndex(of: ">"),
              openBracket < closeBracket
        else {
            return ("", value.trimmingCharacters(in: .whitespaces))
        }
        let name = String(value[..<openBracket])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \""))
        let email = String(value[value.index(after: openBracket)..<closeBracket])
        return (name, email)
    }
}
