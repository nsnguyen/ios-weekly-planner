import Foundation

/// Where an event was created. Drives the small inline glyphs in event rows
/// (Gmail icon for inbox-sourced, etc.) and skips re-extraction loops.
enum EventSource: String, CaseIterable, Hashable, Codable {
    case manual
    case gmail
    case googleCalendar
    case appleMail
}
