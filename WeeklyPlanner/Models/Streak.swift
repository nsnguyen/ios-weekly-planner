import Foundation
import SwiftData

/// A weekly habit / streak the user is tracking. Surfaced on the Review page
/// (Phase 14) with an emoji, name, consecutive-week count, and a 7-day pill
/// row indicating which days of the current week were completed.
@Model
final class Streak {
    @Attribute(.unique) var id: UUID

    var name: String
    var emoji: String
    var consecutiveWeeks: Int

    /// Monday → Sunday completion booleans for the current week.
    /// Always exactly 7 elements; rotated at week boundaries by Phase 14.
    var last7Days: [Bool]

    /// Optional category hint — drives the pill color if set. Stored as raw
    /// String? so SwiftData can index it.
    var categoryHintRaw: String?

    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         consecutiveWeeks: Int = 0,
         last7Days: [Bool] = Array(repeating: false, count: 7),
         categoryHint: Category? = nil)
    {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.consecutiveWeeks = consecutiveWeeks
        self.last7Days = last7Days
        categoryHintRaw = categoryHint?.rawValue
    }
}

extension Streak {
    var categoryHint: Category? {
        get { categoryHintRaw.flatMap(Category.init(rawValue:)) }
        set { categoryHintRaw = newValue?.rawValue }
    }
}
