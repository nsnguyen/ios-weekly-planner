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
              !extracted.title.isEmpty,
              !extracted.startISO.isEmpty,
              let start = Self.parseDate(extracted.startISO)
        else { return nil }

        let end = extracted.endISO.isEmpty ? nil : Self.parseDate(extracted.endISO)
        let category = Category(rawValue: extracted.categoryHint) ?? fallbackCategory
        let fromHeader = message.header("From") ?? ""
        let (fromName, fromEmail) = parseFromHeader(fromHeader)

        return InboxSuggestion(
            gmailMessageID: message.id,
            proposedStart: start,
            proposedEnd: end,
            title: extracted.title,
            fromName: fromName,
            fromEmail: fromEmail,
            category: category,
            subject: message.header("Subject") ?? "",
            bodySnippet: message.snippet,
            proposedLocation: extracted.location.isEmpty ? nil : extracted.location
        )
    }

    /// Tolerant ISO 8601 parser. Foundation Models sometimes returns dates
    /// without a 'Z'/offset (e.g. "2026-05-23T19:00:00"). Tries the strict
    /// formatter first, falls back to one without timezone.
    private static func parseDate(_ raw: String) -> Date? {
        let strict = ISO8601DateFormatter()
        strict.formatOptions = [.withInternetDateTime]
        if let date = strict.date(from: raw) { return date }
        let loose = ISO8601DateFormatter()
        loose.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = loose.date(from: raw) { return date }
        let noTZ = ISO8601DateFormatter()
        noTZ.formatOptions = [.withYear, .withMonth, .withDay, .withTime,
                              .withDashSeparatorInDate, .withColonSeparatorInTime]
        return noTZ.date(from: raw)
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
