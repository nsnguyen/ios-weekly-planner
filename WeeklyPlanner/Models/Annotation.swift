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
    var unitX: Double
    var unitY: Double
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         dayKey: String,
         text: String,
         colorToken: InkColorToken = .ink,
         isBold: Bool = false,
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
        CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
    }
}
