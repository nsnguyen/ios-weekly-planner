import EventKit
import Observation

/// Observable view of the user's EventKit permission state. Settings (Phase 16)
/// reads this; `EventKitSync` reads it before scheduling work.
@MainActor
@Observable
final class EventKitAuthorization {
    private let gateway: any EventKitGateway

    var events: EKAuthorizationStatus
    var reminders: EKAuthorizationStatus

    init(gateway: any EventKitGateway) {
        self.gateway = gateway
        events = gateway.eventsAuthStatus
        reminders = gateway.remindersAuthStatus
    }

    func refresh() {
        events = gateway.eventsAuthStatus
        reminders = gateway.remindersAuthStatus
    }

    /// Triggers the system prompt if status is `.notDetermined`. Re-reads the
    /// status afterwards so observers see the change.
    func requestEventsIfNeeded() async {
        guard gateway.eventsAuthStatus == .notDetermined else { return }
        events = await gateway.requestEventsAccess()
    }

    func requestRemindersIfNeeded() async {
        guard gateway.remindersAuthStatus == .notDetermined else { return }
        reminders = await gateway.requestRemindersAccess()
    }
}

extension EKAuthorizationStatus {
    /// True iff we have permission to read AND write. iOS 17+ split the
    /// "full" permission off from "write-only".
    var isFullAccess: Bool {
        self == .fullAccess
    }

    var isDenied: Bool {
        self == .denied || self == .restricted
    }
}
