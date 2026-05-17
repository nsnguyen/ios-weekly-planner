import Foundation

/// Task priority. Maps to `EKReminder.priority` via `EKReminder+Mapping.swift`:
/// `.high` → 1, `.med` → 5, `.low` → 9. (Apple's encoding, not ours.)
enum Priority: String, CaseIterable, Hashable, Codable, Comparable {
    case low
    case med
    case high

    /// Sort weight. Higher value = more urgent (sorts first descending).
    var sortWeight: Int {
        switch self {
        case .low: 0
        case .med: 1
        case .high: 2
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.sortWeight < rhs.sortWeight
    }
}
