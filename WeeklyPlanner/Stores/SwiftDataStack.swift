import Foundation
import SwiftData

/// Owns the single app-wide `ModelContainer` and exposes a few factories
/// for tests + previews. SwiftData's `@Model` types are registered here so
/// changes to the schema show up in one place.
@MainActor
enum SwiftDataStack {
    static let allModels: [any PersistentModel.Type] = [
        Event.self,
        TaskItem.self,
        InboxSuggestion.self,
        AIInsight.self,
        Streak.self,
        UserSettings.self,
        Note.self,
        Annotation.self,
    ]

    /// Lazily-initialised production container, on-disk. Crashes on
    /// initialisation failure — there's no graceful recovery if the schema
    /// can't be opened, and the failure mode is loud-and-fatal by design.
    static let production: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(allModels),
                                      configurations: [ModelConfiguration(isStoredInMemoryOnly: false)])
        } catch {
            fatalError("Failed to open SwiftData container: \(error)")
        }
    }()

    /// In-memory container for tests and SwiftUI previews. Fresh per call.
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema(allModels),
                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }
}
