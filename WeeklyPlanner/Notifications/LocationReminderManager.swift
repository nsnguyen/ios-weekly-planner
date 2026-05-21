import CoreLocation
import Foundation
import UserNotifications
import os

/// Manages the iOS-mandated 20-region cap via a priority queue: lower
/// `proximityInDays` always wins. On every `register(...)` call we:
///   1. Drop any prior registration for the same event id (so re-scheduling
///      isn't lossy).
///   2. Insert the new entry.
///   3. Sort by `proximityInDays` ascending.
///   4. Cap to the top 20 — entries that fall off the cliff stop monitoring.
///
/// On region entry the `CLLocationManagerDelegate` callback finds the matching
/// entry by region identifier, asks the stored content factory for a fresh
/// `UNMutableNotificationContent`, and adds the request via `NotificationCentering`.
@MainActor
final class LocationReminderManager: NSObject, LocationRegistering, CLLocationManagerDelegate {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")
    private static let maxRegions = 20
    private static let escalationThresholdDays = 1

    private struct Entry {
        let eventID: UUID
        let regionIdentifier: String
        let region: CLCircularRegion
        let contentFactory: () -> UNMutableNotificationContent
        let proximityInDays: Int
    }

    private var entries: [Entry] = []
    private let location: any LocationManaging
    private let center: any NotificationCentering

    init(location: any LocationManaging, center: any NotificationCentering) {
        self.location = location
        self.center = center
        super.init()
        self.location.locationDelegate = self
    }

    // MARK: LocationRegistering

    @discardableResult
    func register(eventID: UUID,
                  reminder: LocationReminder,
                  content: @escaping () -> UNMutableNotificationContent,
                  proximityInDays: Int) -> String?
    {
        let identifier = "loc-\(eventID.uuidString)"
        // Remove any existing entry for this event id, both from our priority
        // queue and from the OS's active set.
        if let existing = entries.first(where: { $0.eventID == eventID }) {
            location.stopMonitoring(for: existing.region)
            entries.removeAll { $0.eventID == eventID }
        }

        let circle = CLCircularRegion(center: reminder.coordinate,
                                       radius: reminder.radiusMeters,
                                       identifier: identifier)
        circle.notifyOnEntry = true
        circle.notifyOnExit = false

        let entry = Entry(eventID: eventID,
                          regionIdentifier: identifier,
                          region: circle,
                          contentFactory: content,
                          proximityInDays: proximityInDays)
        entries.append(entry)

        requestAuthorizationIfNeeded(proximityInDays: proximityInDays)
        rebalanceMonitoring()

        // Returned identifier == the request identifier the eventual
        // delivered notification will carry.
        return identifier
    }

    func unregister(eventID: UUID) {
        guard let existing = entries.first(where: { $0.eventID == eventID }) else { return }
        location.stopMonitoring(for: existing.region)
        entries.removeAll { $0.eventID == eventID }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor [weak self] in
            await self?.handleEntry(regionIdentifier: identifier)
        }
    }

    // MARK: - Private

    private func handleEntry(regionIdentifier: String) async {
        guard let entry = entries.first(where: { $0.regionIdentifier == regionIdentifier }) else { return }
        let content = entry.contentFactory()
        let request = UNNotificationRequest(identifier: entry.regionIdentifier,
                                            content: content,
                                            trigger: nil)
        do {
            try await center.add(request)
            Self.log.info("Delivered region-entry notification for \(entry.eventID, privacy: .public)")
        } catch {
            Self.log.error("Region-entry add failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func requestAuthorizationIfNeeded(proximityInDays: Int) {
        switch location.authorizationStatus {
        case .notDetermined:
            location.requestWhenInUseAuthorization()
        case .authorizedWhenInUse where proximityInDays > Self.escalationThresholdDays:
            location.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func rebalanceMonitoring() {
        // Sort by proximity ascending; cap to maxRegions.
        entries.sort { $0.proximityInDays < $1.proximityInDays }
        let keepers = Array(entries.prefix(Self.maxRegions))
        let dropped = entries.dropFirst(Self.maxRegions)
        for entry in dropped {
            location.stopMonitoring(for: entry.region)
        }
        entries = keepers

        // Make sure the OS is monitoring exactly our keeper set.
        let monitored = location.monitoredRegions.map(\.identifier)
        for entry in entries where monitored.contains(entry.regionIdentifier) == false {
            location.startMonitoring(for: entry.region)
        }
    }
}
