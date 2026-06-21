import Foundation

/// One-shot, thread-safe router that delivers exactly ONE `Result` to a sink,
/// regardless of whether the sink is registered (`onReady`) before or after the
/// result arrives (`deliver`). The first `deliver` wins; later ones are no-ops.
///
/// This is the cancellation-safety core of the GIDSignIn callback→continuation
/// bridge in `RealGIDSigningClient`: the SDK callback and task cancellation both
/// call `deliver`, and whichever is first resumes the continuation exactly once.
/// Without it, a cancelled sign-in Task leaves the continuation suspended
/// forever (the "leaked its continuation" hang) — or, if both fired, would
/// double-resume a `CheckedContinuation` and trap.
final class OneShotResult<Success, Failure: Error>: @unchecked Sendable {
    private let lock = NSLock()
    private var sink: ((Result<Success, Failure>) -> Void)?
    private var pending: Result<Success, Failure>?
    private var delivered = false

    /// Register the sink (typically a continuation's `resume(with:)`). Expected
    /// to be called once. If a result already arrived, it is delivered now.
    func onReady(_ sink: @escaping (Result<Success, Failure>) -> Void) {
        lock.lock()
        if delivered { lock.unlock(); return }
        if let pending {
            delivered = true
            lock.unlock()
            sink(pending)
        } else {
            self.sink = sink
            lock.unlock()
        }
    }

    /// Deliver a result. The first call wins; subsequent calls (and a result
    /// arriving after `delivered`) are ignored.
    func deliver(_ result: Result<Success, Failure>) {
        lock.lock()
        guard !delivered, pending == nil else { lock.unlock(); return }
        if let sink {
            delivered = true
            self.sink = nil
            lock.unlock()
            sink(result)
        } else {
            pending = result
            lock.unlock()
        }
    }
}
