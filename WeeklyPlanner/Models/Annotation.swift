import Foundation
import SwiftData

/// Free-text written directly on a Day page (Phase 34). Position is
/// unit-space (0…1) relative to the page's annotation layer so it
/// survives rotation and size changes.
@Model
final class Annotation {
    @Attribute(.unique) var id: UUID
    /// `"<weekOffset>:<dayIdx>"` — same scheme as `AIInsight.dayKey`.
    var dayKey: String
    var text: String
    /// `InkColorToken` raw value (stable token, never a raw platform color).
    var colorTokenRaw: String
    var isBold: Bool
    /// True while the note sits where the stacking gesture placed it — the
    /// machine may restack it when content grows underneath. A user drag
    /// clears it forever (the machine never moves what the user placed).
    /// The property-level `= false` is load-bearing: SwiftData lightweight
    /// migration takes the schema default from the declaration (not the
    /// init), so pre-feature rows decode as pinned instead of crashing the
    /// container open (same lesson as AIInsight, commit 1d48e6d).
    var autoPlaced: Bool = false
    var unitX: Double
    var unitY: Double
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         dayKey: String,
         text: String,
         colorToken: InkColorToken = .ink,
         isBold: Bool = false,
         autoPlaced: Bool = false,
         unitX: Double,
         unitY: Double,
         createdAt: Date = .init(),
         updatedAt: Date = .init())
    {
        self.id = id
        self.dayKey = dayKey
        self.text = text
        colorTokenRaw = colorToken.rawValue
        self.isBold = isBold
        self.autoPlaced = autoPlaced
        self.unitX = unitX
        self.unitY = unitY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Annotation {
    var colorToken: InkColorToken {
        get { InkColorToken(rawValue: colorTokenRaw) ?? .ink }
        set { colorTokenRaw = newValue.rawValue }
    }

    static func key(weekOffset: Int, dayIdx: Int) -> String {
        "\(weekOffset):\(dayIdx)"
    }

    static func clampUnit(_ point: CGPoint) -> CGPoint {
        // Non-finite input (NaN/inf from degenerate gesture geometry) would
        // persist and strand the annotation off-screen — recover to center.
        let x = point.x.isFinite ? min(max(point.x, 0), 1) : 0.5
        let y = point.y.isFinite ? min(max(point.y, 0), 1) : 0.5
        return CGPoint(x: x, y: y)
    }
}
