import Foundation
import SwiftData

/// Per-day AI-generated sticky note. Rendered as the masking-tape paper
/// rectangle on the day page (top-right). Multiple insights can coexist
/// for the same `(weekOffset, dayIdx)` cell — one per `kind`. The
/// orchestrator enforces logical uniqueness on `(dayKey, kind)` at
/// persist time; SwiftData no longer carries a `dayKey` unique
/// constraint because Phase 24 cascades up to 3 insights per day.
///
/// V1 rows (pre-Phase-24) lacked `kind` / `actionURL` / `priority`. The
/// default values below give them a lightweight migration:
/// `kind = .encouragement`, `actionURL = nil`, `priority = 9` — i.e.
/// "fallback encouragement, lowest cascade priority."
@Model
final class AIInsight {
    @Attribute(.unique) var id: UUID

    /// `"<weekOffset>:<dayIdx>"`, e.g., `"0:5"` for Saturday of the current week.
    /// **No longer `@Attribute(.unique)`** — multiple insights can share a day
    /// (one per `kind`). The orchestrator deletes old rows for the same
    /// `(dayKey, kind)` before inserting fresh ones.
    var dayKey: String

    var dateGenerated: Date
    var text: String

    /// Sticky paper color hex. Defaults to `#FFE680` (yellow) for
    /// encouragement; per-kind colors are set by the orchestrator
    /// from `InsightKind.colorHex`.
    var colorHex: String

    /// Tilt angle in degrees, typically ±3 to ±5°.
    var tiltDegrees: Double

    var dismissed: Bool

    // MARK: - Phase 24 additions

    /// `InsightKind` raw value. Stored as String so SwiftData predicates
    /// can filter on it directly without bridging the enum.
    ///
    /// Property-level default of `"encouragement"` lets SwiftData's
    /// lightweight migration assign existing V1 rows a value without
    /// a custom `SchemaMigrationPlan`. The init still sets this from
    /// the `kind:` parameter; the default exists purely for migration.
    var kindRaw: String = "encouragement"

    /// Deep link or external URL the sticky body taps open. Examples:
    /// `"weeklyplanner://event/<uuid>"`, `"http://maps.apple.com/?daddr=…"`,
    /// `"weather://"`. `nil` for `.encouragement` (legacy fold/expand only).
    var actionURL: String?

    /// Cascade sort order. Lower = earlier in the stack. Defaults to 9
    /// (fallback `encouragement` priority).
    ///
    /// Property-level default of `9` lets lightweight migration assign
    /// existing V1 rows the fallback floor without a custom migration
    /// plan; the init still sets this from the `priority:` parameter.
    var priority: Int = 9

    init(id: UUID = UUID(),
         dayKey: String,
         dateGenerated: Date = .init(),
         text: String,
         colorHex: String = "#FFE680",
         tiltDegrees: Double = 0,
         dismissed: Bool = false,
         kind: InsightKind = .encouragement,
         actionURL: String? = nil,
         priority: Int = 9)
    {
        self.id = id
        self.dayKey = dayKey
        self.dateGenerated = dateGenerated
        self.text = text
        self.colorHex = colorHex
        self.tiltDegrees = tiltDegrees
        self.dismissed = dismissed
        self.kindRaw = kind.rawValue
        self.actionURL = actionURL
        self.priority = priority
    }
}

extension AIInsight {
    /// Builds a `dayKey` from week + day indices. Both Monday-based.
    static func key(weekOffset: Int, dayIdx: Int) -> String {
        "\(weekOffset):\(dayIdx)"
    }

    /// Typed accessor over `kindRaw`. Defaults to `.encouragement` if a
    /// V1 row migrated in with an empty / unknown raw value.
    var kind: InsightKind {
        get { InsightKind(rawValue: kindRaw) ?? .encouragement }
        set { kindRaw = newValue.rawValue }
    }
}

// TEMP: moved to Intelligence/InsightGenerator.swift in Task 2
enum InsightKind: String, CaseIterable, Codable, Sendable {
    case travel, weather, keyword, inbox, encouragement
}
