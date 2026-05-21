import Foundation
import UserNotifications
@testable import WeeklyPlanner

/// Records every call. Schedulers/managers under test inspect these arrays
/// for assertions. All methods complete synchronously — async signatures are
/// kept only to satisfy the protocol.
@MainActor
final class FakeNotificationCenter: NotificationCentering {
    var stubAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var stubAuthorizationGranted: Bool = true
    var stubAuthorizationError: Error?

    private(set) var requestedAuthorizationOptions: UNAuthorizationOptions?
    private(set) var registeredCategories: Set<UNNotificationCategory> = []
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var removeAllCount: Int = 0

    func authorizationStatus() async -> UNAuthorizationStatus { stubAuthorizationStatus }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions = options
        if let error = stubAuthorizationError { throw error }
        return stubAuthorizationGranted
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        registeredCategories = categories
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func pendingRequests() async -> [UNNotificationRequest] { addedRequests }

    func removePending(withIdentifiers identifiers: [String]) {
        addedRequests.removeAll { identifiers.contains($0.identifier) }
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllPending() {
        removedIdentifiers.append(contentsOf: addedRequests.map(\.identifier))
        addedRequests.removeAll()
        removeAllCount += 1
    }
}
