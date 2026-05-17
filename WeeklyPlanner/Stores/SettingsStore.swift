import Foundation
import SwiftData

@MainActor
protocol SettingsStoring: AnyObject {
    func current() throws -> UserSettings
    func update(_ apply: (UserSettings) -> Void) throws
}

@MainActor
final class SwiftDataSettingsStore: SettingsStoring {
    private let context: ModelContext
    private let changeSubject = NotificationCenter.default

    init(context: ModelContext) {
        self.context = context
    }

    /// Returns the singleton `UserSettings` row, creating it on first call.
    func current() throws -> UserSettings {
        if let existing = try context.fetch(FetchDescriptor<UserSettings>()).first {
            return existing
        }
        let fresh = UserSettings()
        context.insert(fresh)
        try context.save()
        return fresh
    }

    func update(_ apply: (UserSettings) -> Void) throws {
        let settings = try current()
        apply(settings)
        settings.updatedAt = .init()
        try context.save()
        changeSubject.post(name: .settingsStoreDidChange, object: nil)
    }
}

extension Notification.Name {
    static let settingsStoreDidChange = Notification.Name("WeeklyPlanner.SettingsStore.didChange")
}
