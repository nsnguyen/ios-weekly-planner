import Foundation

/// Pre-call sanitation + short-circuit checks. Kept narrow and pure so the
/// rules are unambiguous and easy to fuzz.
enum SafetyGuard {
    /// Trims whitespace, strips control characters, and clamps to 600
    /// characters. Anything beyond 600 is silently truncated — long
    /// prompts blow the token budget and rarely improve answers.
    static func sanitize(_ raw: String) -> String {
        let stripped = raw.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }
        let trimmed = String(String.UnicodeScalarView(stripped))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 600 {
            return trimmed
        }
        return String(trimmed.prefix(600))
    }

    /// Returns `true` when the model must NOT be invoked. Today this is
    /// only the user-disabled toggle in `UserSettings`; Phase 13-b can add
    /// thermal-state and inflight-rate-limit checks.
    static func shouldShortCircuit(context: PlannerContext) -> Bool {
        !context.appleIntelligenceEnabled
    }
}
