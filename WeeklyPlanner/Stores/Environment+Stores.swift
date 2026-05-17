import Foundation
import SwiftUI

/// SwiftUI environment plumbing for the two stores the Day page reads from.
///
/// Production wires real `SwiftDataEventStore` / `SwiftDataInboxStore`
/// instances at the `App` entry point; previews and ad-hoc views that don't
/// need real persistence pick up the stub defaults — both return empty
/// arrays from every read and no-op every write — so they never crash for
/// want of a SwiftData container.
///
/// The stubs are intentionally `final class` (not structs) to match the
/// `AnyObject` constraint on `EventStoring` / `InboxStoring`, and they are
/// `@MainActor` to satisfy the protocols' main-actor isolation.
extension EnvironmentValues {
    /// The active `EventStoring` for this subtree. Defaults to `StubEventStore`.
    @Entry var eventStore: any EventStoring = StubEventStore()

    /// The active `InboxStoring` for this subtree. Defaults to `StubInboxStore`.
    @Entry var inboxStore: any InboxStoring = StubInboxStore()
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
