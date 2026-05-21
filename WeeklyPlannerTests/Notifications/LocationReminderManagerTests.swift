import CoreLocation
import UserNotifications
import XCTest
@testable import WeeklyPlanner

@MainActor
final class LocationReminderManagerTests: XCTestCase {

    private var location: FakeLocationManager!
    private var center: FakeNotificationCenter!
    private var manager: LocationReminderManager!

    override func setUp() async throws {
        location = FakeLocationManager()
        center = FakeNotificationCenter()
        manager = LocationReminderManager(location: location, center: center)
    }

    func testRegisterUpTo20Regions() {
        for i in 0..<25 {
            let id = UUID()
            _ = manager.register(
                eventID: id,
                reminder: LocationReminder(name: "P\(i)", latitude: 0, longitude: 0, radiusMeters: 150),
                content: { UNMutableNotificationContent() },
                proximityInDays: 5    // All same priority — keep insertion order.
            )
        }
        XCTAssertLessThanOrEqual(location.monitoredRegions.count, 20)
    }

    func testPriorityKeepsTodayEventsActive() {
        // Fill with far-future events first.
        var farIDs: [UUID] = []
        for i in 0..<20 {
            let id = UUID()
            farIDs.append(id)
            _ = manager.register(
                eventID: id,
                reminder: LocationReminder(name: "Far\(i)", latitude: 0, longitude: 0, radiusMeters: 150),
                content: { UNMutableNotificationContent() },
                proximityInDays: 7
            )
        }
        XCTAssertEqual(location.monitoredRegions.count, 20)

        // Now register a today event. It should evict the lowest-priority far-future one.
        let todayID = UUID()
        _ = manager.register(
            eventID: todayID,
            reminder: LocationReminder(name: "Today", latitude: 0, longitude: 0, radiusMeters: 150),
            content: { UNMutableNotificationContent() },
            proximityInDays: 0
        )

        XCTAssertEqual(location.monitoredRegions.count, 20)
        XCTAssertTrue(location.monitoredRegions.contains { $0.identifier.contains(todayID.uuidString) })
    }

    func testRegionEntryFiresNotification() async {
        let id = UUID()
        _ = manager.register(
            eventID: id,
            reminder: LocationReminder(name: "Marina", latitude: 37.8, longitude: -122.4, radiusMeters: 150),
            content: {
                let c = UNMutableNotificationContent()
                c.title = "Arrived"
                return c
            },
            proximityInDays: 0
        )
        let region = try! XCTUnwrap(location.monitoredRegions.first { $0.identifier.contains(id.uuidString) })

        location.simulateEntry(region)

        // Allow the async add to flush.
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.content.title, "Arrived")
    }

    func testEscalateToAlwaysAuthOnFarFutureEvent() {
        location.authorizationStatus = .authorizedWhenInUse
        _ = manager.register(
            eventID: UUID(),
            reminder: LocationReminder(name: "Beach", latitude: 0, longitude: 0, radiusMeters: 150),
            content: { UNMutableNotificationContent() },
            proximityInDays: 5    // >24h.
        )
        XCTAssertEqual(location.alwaysRequestCount, 1)
    }
}
