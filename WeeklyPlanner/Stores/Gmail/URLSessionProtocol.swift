import Foundation

/// The slice of `URLSession` that `GmailClient` uses. Production wires
/// `URLSession.shared`; tests wire a `URLSession` configured with a
/// `URLProtocolStub` so no real network traffic happens.
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
