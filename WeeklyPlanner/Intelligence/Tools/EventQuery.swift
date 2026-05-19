import Foundation

/// Compact filter struct used by `FindEventsTool` and the
/// `EventStoring.events(matching:)` overload. All fields are additive — an
/// empty array or `nil` means "don't filter on this axis".
struct EventQuery: Sendable, Equatable {
    let dateRange: ClosedRange<Date>
    let categories: [Category]?
    let keywords: [String]
    let personName: String?
}
