import Foundation

/// `NotificationCenter.addObserver(forName:object:queue:using:)` returns
/// an `any NSObjectProtocol` token that is not `Sendable`. Stores wrap that
/// token here so an `AsyncStream.Continuation`'s `@Sendable` `onTermination`
/// closure can hold onto it safely.
///
/// The wrapper is `@unchecked Sendable` because the token is opaque, never
/// mutated by us, and only handed back to `NotificationCenter.removeObserver`.
final class NotificationObserverToken: @unchecked Sendable {
    private let token: any NSObjectProtocol
    private let center: NotificationCenter

    init(token: any NSObjectProtocol, center: NotificationCenter) {
        self.token = token
        self.center = center
    }

    func remove() {
        center.removeObserver(token)
    }
}
