import Foundation
import SwiftData

extension Notification.Name {
    static let eventTemplateStoreDidChange = Notification.Name("WeeklyPlanner.EventTemplateStore.didChange")
}

@MainActor
protocol EventTemplateStoring: AnyObject {
    func templates() throws -> [EventTemplateRecord]
    func add(title: String, category: Category, durationMinutes: Int) throws
    func delete(id: UUID) throws
    func seedIfNeeded(from curated: [EventTemplate], settings: any SettingsStoring) throws
}

@MainActor
final class SwiftDataEventTemplateStore: EventTemplateStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func templates() throws -> [EventTemplateRecord] {
        let descriptor = FetchDescriptor<EventTemplateRecord>(sortBy: [SortDescriptor(\.sortOrder)])
        return try context.fetch(descriptor)
    }

    func add(title: String, category: Category, durationMinutes: Int) throws {
        let nextOrder = ((try? templates().last?.sortOrder) ?? -1) + 1
        context.insert(EventTemplateRecord(title: title,
                                           categoryRaw: category.rawValue,
                                           durationMinutes: durationMinutes,
                                           sortOrder: nextOrder))
        try context.save()
        NotificationCenter.default.post(name: .eventTemplateStoreDidChange, object: nil)
    }

    func delete(id: UUID) throws {
        guard let record = try templates().first(where: { $0.id == id }) else { return }
        context.delete(record)
        try context.save()
        NotificationCenter.default.post(name: .eventTemplateStoreDidChange, object: nil)
    }

    /// Seed curated defaults exactly once per install; an emptied list stays empty.
    func seedIfNeeded(from curated: [EventTemplate], settings: any SettingsStoring) throws {
        guard try !settings.current().eventTemplatesSeeded else { return }
        for (index, template) in curated.enumerated() {
            context.insert(EventTemplateRecord(title: template.title,
                                               categoryRaw: template.category.rawValue,
                                               durationMinutes: template.durationMinutes,
                                               alertMinutes: template.alertMinutes,
                                               sortOrder: index))
        }
        try context.save()
        try settings.update { $0.eventTemplatesSeeded = true }
        NotificationCenter.default.post(name: .eventTemplateStoreDidChange, object: nil)
    }
}
