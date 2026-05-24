import Foundation
import SwiftData
import SwiftUI

/// Small utility that resolves the `AIInsight` for a given `(weekOffset, dayIdx)`
/// pair, plus a tiny color-math helper used by the folded-tab gradient.
///
/// Phase 07 only wires the SwiftData read path — production "generate on miss"
/// behaviour is owned by the Phase 13 Foundation Models pipeline, which writes
/// new `AIInsight` rows the same store this enum reads from. Until then, the
/// only insights present are those bundled in `seed-insights.json`.
///
/// Both members are `static` so callers (views and tests) don't have to thread
/// an instance through; `@MainActor` is required because every `ModelContext`
/// touch in the app is main-actor isolated.
@MainActor
enum StickyNoteGenerator {
    /// Returns the most recently generated, non-dismissed insight for the
    /// given `(weekOffset, dayIdx)` cell, or `nil` if none exists. The fetch
    /// filters on `dayKey == "<weekOffset>:<dayIdx>"` so callers don't need
    /// to know the encoding.
    static func insight(forWeekOffset weekOffset: Int,
                        dayIdx: Int,
                        in context: ModelContext) -> AIInsight?
    {
        let key = AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx)
        let desc = FetchDescriptor<AIInsight>(predicate: #Predicate { $0.dayKey == key && !$0.dismissed })
        return try? context.fetch(desc).first
    }

    /// Returns up to 3 non-dismissed insights for the given day, sorted by
    /// `priority` ascending. Phase 24 — replaces the single-insight pattern
    /// with the cascade.
    static func insights(forWeekOffset weekOffset: Int,
                         dayIdx: Int,
                         in context: ModelContext) -> [AIInsight]
    {
        let key = AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx)
        let desc = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.dayKey == key && !$0.dismissed },
            sortBy: [SortDescriptor(\.priority, order: .forward)])
        let rows = (try? context.fetch(desc)) ?? []
        return Array(rows.prefix(StickyOrchestrator.cascadeCap))
    }

    /// Darkens a hex color by the given percent (0–100). Used to shade the
    /// folded-tab gradient so the back of the sticky reads as a slightly
    /// darker version of the paper color. `shade("#FFE680", percent: 20)` →
    /// roughly `rgb(204, 184, 102)`. Negative percents are clamped to 0
    /// (the input color is returned unchanged) — `shade` only ever darkens.
    static func shade(_ hex: String, percent: Int) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF)
        let g = Double((value >> 8) & 0xFF)
        let b = Double(value & 0xFF)
        // Clamp percent to [0, 100]: shade only darkens, never brightens.
        let clampedPercent = max(0, min(100, percent))
        let factor = 1.0 - Double(clampedPercent) / 100.0
        return Color(.sRGB,
                     red: r * factor / 255.0,
                     green: g * factor / 255.0,
                     blue: b * factor / 255.0,
                     opacity: 1.0)
    }
}
