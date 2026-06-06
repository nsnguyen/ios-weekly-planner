import Foundation

/// A curated quick-fill preset for the create-event sheet (Phase 36a #41
/// "more template"). Value-type set — user-defined templates are a later
/// phase if requested.
struct EventTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let category: Category
    let durationMinutes: Int
    /// `nil` = no alert preset.
    let alertMinutes: Int?
}

extension EventTemplate {
    static let curated: [EventTemplate] = [
        EventTemplate(id: "gym", title: "Gym", category: .health, durationMinutes: 60, alertMinutes: 15),
        EventTemplate(id: "standup", title: "Standup", category: .work, durationMinutes: 15, alertMinutes: 5),
        EventTemplate(id: "lunch", title: "Lunch", category: .personal, durationMinutes: 60, alertMinutes: nil),
        EventTemplate(id: "call", title: "Call", category: .family, durationMinutes: 30, alertMinutes: 5),
        EventTemplate(id: "errands", title: "Errands", category: .personal, durationMinutes: 45, alertMinutes: nil),
        EventTemplate(id: "datenight", title: "Date night", category: .family, durationMinutes: 120, alertMinutes: 60),
    ]
}

extension EventComposerState {
    /// Pre-fill from a template. Keeps the user's chosen start anchor;
    /// sets title/category/duration/alert.
    func apply(_ template: EventTemplate) {
        title = template.title
        category = template.category
        end = start.addingTimeInterval(TimeInterval(template.durationMinutes * 60))
        if let minutes = template.alertMinutes {
            alertOn = true
            alertMinutes = minutes
        } else {
            alertOn = false
        }
    }
}
