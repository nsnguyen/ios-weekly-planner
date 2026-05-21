import CoreLocation
import Foundation
@testable import WeeklyPlanner

@MainActor
final class FakeLocationManager: LocationManaging {
    var locationDelegate: CLLocationManagerDelegate?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var monitoredRegions: Set<CLRegion> = []

    private(set) var whenInUseRequestCount = 0
    private(set) var alwaysRequestCount = 0

    func requestWhenInUseAuthorization() { whenInUseRequestCount += 1 }
    func requestAlwaysAuthorization()    { alwaysRequestCount += 1 }

    func startMonitoring(for region: CLRegion) {
        monitoredRegions.insert(region)
    }

    func stopMonitoring(for region: CLRegion) {
        monitoredRegions.remove(region)
    }

    /// Simulates region entry by invoking the delegate.
    func simulateEntry(_ region: CLRegion) {
        guard let manager = locationDelegate else { return }
        let fakeCL = CLLocationManager()
        manager.locationManager?(fakeCL, didEnterRegion: region)
    }
}
