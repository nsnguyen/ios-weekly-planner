import Foundation

/// The six event categories, used everywhere events are rendered.
/// Raw values are stable identifiers — persisted in SwiftData and EventKit.
enum Category: String, CaseIterable, Hashable, Codable {
    case work
    case personal
    case health
    case family
    case focus
    case travel
}
