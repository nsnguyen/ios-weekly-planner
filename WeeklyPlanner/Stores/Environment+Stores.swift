import Foundation
import SwiftUI

/// SwiftUI environment plumbing for the stores the Day page reads from.
///
/// Production wires real `SwiftDataEventStore` / `SwiftDataInboxStore` /
/// `SwiftDataTaskStore` instances at the `App` entry point; previews and
/// ad-hoc views that don't need real persistence pick up the stub defaults —
/// all three return empty arrays from every read and no-op every write — so
/// they never crash for want of a SwiftData container.
///
/// The stubs are intentionally `final class` (not structs) to match the
/// `AnyObject` constraint on the protocols, and they are `@MainActor` to
/// satisfy the protocols' main-actor isolation.
extension EnvironmentValues {
    /// The active `EventStoring` for this subtree. Defaults to `StubEventStore`.
    @Entry var eventStore: any EventStoring = StubEventStore()

    /// The active `InboxStoring` for this subtree. Defaults to `StubInboxStore`.
    @Entry var inboxStore: any InboxStoring = StubInboxStore()

    /// The active `TaskStoring` for this subtree. Defaults to `StubTaskStore`.
    @Entry var taskStore: any TaskStoring = StubTaskStore()

    /// The live Intelligence service for this subtree, or `nil` in
    /// previews / tests that don't set it. Phase 13 producers (AI
    /// overlay, event sheet suggestion) read this and skip the AI
    /// pathway when it's missing.
    @Entry var intelligenceService: (any IntelligenceService)? = nil
}

// MARK: - Stubs

/// No-op `EventStoring` used as the default environment value. Reads always
/// return an empty array; writes are silently dropped. Lets SwiftUI previews
/// render the Day page without standing up a real SwiftData container.
///
/// The class itself is `@MainActor` to satisfy `EventStoring`'s isolation
/// requirement, but `init()` is `nonisolated` so the SwiftUI `@Entry` macro
/// (which builds its default value in a synchronous nonisolated context) can
/// construct one without a hop.
@MainActor
final class StubEventStore: EventStoring {
    /// Nonisolated initializer so the `@Entry` macro can synthesize a default
    /// value in the synchronous, nonisolated initializer of
    /// `EnvironmentValues`. The stub holds no mutable state, so there's
    /// nothing to isolate at init time.
    nonisolated init() {}

    func events(forWeekOffset _: Int, today _: Date) async throws -> [Event] {
        []
    }

    func event(id _: UUID) async throws -> Event? {
        nil
    }

    func upsert(_: Event) async throws {}
    func delete(id _: UUID) async throws {}
    func events(matching _: EventQuery) async throws -> [Event] { [] }
}

/// No-op `InboxStoring` companion to `StubEventStore`. Same semantics:
/// empty reads, dropped writes.
@MainActor
final class StubInboxStore: InboxStoring {
    /// Nonisolated initializer for the same reason as `StubEventStore.init()`.
    nonisolated init() {}

    func pending(forWeekOffset _: Int, today _: Date) async throws -> [InboxSuggestion] {
        []
    }

    func suggestion(id _: UUID) async throws -> InboxSuggestion? {
        nil
    }

    func upsert(_: InboxSuggestion) async throws {}
    func accept(id _: UUID) async throws {}
    func dismiss(id _: UUID) async throws {}
}

/// No-op `TaskStoring` companion to `StubEventStore`/`StubInboxStore`. Same
/// semantics: empty reads, dropped writes. Used as the default value for
/// `@Environment(\.taskStore)` so previews and ad-hoc views never crash.
@MainActor
final class StubTaskStore: TaskStoring {
    /// Nonisolated initializer for the same reason as `StubEventStore.init()`.
    nonisolated init() {}

    func tasks(forWeekOffset _: Int, today _: Date) async throws -> [TaskItem] {
        []
    }

    func task(id _: UUID) async throws -> TaskItem? {
        nil
    }

    func upsert(_: TaskItem) async throws {}
    func toggle(id _: UUID) async throws {}
    func delete(id _: UUID) async throws {}
}
