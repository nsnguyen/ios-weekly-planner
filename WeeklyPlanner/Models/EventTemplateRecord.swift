import Foundation
import SwiftData

/// A user-editable quick-add chip for the create-event sheet (Phase 42 #68).
/// Replaces the hardcoded `EventTemplate.curated` array as the source of
/// truth; `EventTemplate` remains the value type the composer consumes.
@Model
final class EventTemplateRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRaw: String
    var durationMinutes: Int
    var alertMinutes: Int?
    var sortOrder: Int

    init(id: UUID = UUID(),
         title: String,
         categoryRaw: String,
         durationMinutes: Int,
         alertMinutes: Int? = nil,
         sortOrder: Int)
    {
        self.id = id
        self.title = title
        self.categoryRaw = categoryRaw
        self.durationMinutes = durationMinutes
        self.alertMinutes = alertMinutes
        self.sortOrder = sortOrder
    }
}

extension EventTemplateRecord {
    var category: Category {
        Category(rawValue: categoryRaw) ?? .personal
    }

    var asTemplate: EventTemplate {
        EventTemplate(id: id.uuidString,
                      title: title,
                      category: category,
                      durationMinutes: durationMinutes,
                      alertMinutes: alertMinutes)
    }
}
