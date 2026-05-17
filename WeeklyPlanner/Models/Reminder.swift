import Foundation

/// An alert configured on an event or task. Two flavors:
///   - `.timeBefore(minutes:)` — fires N minutes before `Event.start` /
///      `TaskItem.due`.
///   - `.onArrive(_:)` — geofenced; fires when the user enters the region.
///
/// Codable conformance is synthesized by the compiler. The JSON shape is
/// `{ "timeBefore": { "minutes": 15 } }` or
/// `{ "onArrive": { "name": "Marina", "latitude": ..., "longitude": ..., "radiusMeters": 150 } }`.
enum Reminder: Codable, Equatable, Hashable {
    case timeBefore(minutes: Int)
    case onArrive(LocationReminder)
}
