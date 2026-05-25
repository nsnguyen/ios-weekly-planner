import Foundation
import Observation

/// Holds the pending deep-link request set by `AppDelegate+Notifications`
/// when the user taps a notification (or cold-launches via one). `AppShell`
/// observes `pending`, consumes it once the matching sheet is presented.
@MainActor
@Observable
final class DeepLinkRouter {
    enum Destination: Equatable {
        case event(UUID)
        case task(UUID)
        case inbox(dayKey: String)
    }

    private(set) var pending: Destination?

    nonisolated init() {}

    func request(_ destination: Destination) {
        pending = destination
    }

    /// Reads and clears the pending value. Use this when the consumer has
    /// committed to navigating — no re-firing.
    @discardableResult
    func consume() -> Destination? {
        defer { pending = nil }
        return pending
    }
}
