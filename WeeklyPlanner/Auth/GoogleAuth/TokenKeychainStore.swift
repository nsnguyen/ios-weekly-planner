import Foundation
import KeychainAccess

/// Generic Codable wrapper around `KeychainAccess`. One slot per `serviceID`
/// — the value is JSON-encoded and stored under the well-known key `"value"`.
/// The serviceID acts as the namespace (production passes
/// `"com.weeklyplanner.WeeklyPlanner.google"`; tests pass a per-test UUID
/// suffix).
///
/// Errors from `KeychainAccess` propagate as `Error`. `load()` returns `nil`
/// when nothing is stored; it does NOT throw for the empty case.
struct TokenKeychainStore<Value: Codable> {
    private let keychain: Keychain
    private static var slotKey: String { "value" }

    init(serviceID: String) {
        keychain = Keychain(service: serviceID)
    }

    func save(_ value: Value) throws {
        let data = try JSONEncoder().encode(value)
        try keychain.set(data, key: Self.slotKey)
    }

    func load() throws -> Value? {
        guard let data = try keychain.getData(Self.slotKey) else { return nil }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func clear() throws {
        try keychain.remove(Self.slotKey)
    }
}
