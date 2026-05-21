import CoreLocation
import Foundation

/// Subset of `CLLocationManager` that `LocationReminderManager` calls into.
/// Pulled into a protocol so tests can drive region entry without monitoring
/// a real device.
@MainActor
protocol LocationManaging: AnyObject {
    var locationDelegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var monitoredRegions: Set<CLRegion> { get }

    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startMonitoring(for region: CLRegion)
    func stopMonitoring(for region: CLRegion)
}

@MainActor
final class LiveLocationManager: NSObject, LocationManaging {
    private let manager: CLLocationManager

    var locationDelegate: CLLocationManagerDelegate? {
        get { manager.delegate }
        set { manager.delegate = newValue }
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var monitoredRegions: Set<CLRegion> { manager.monitoredRegions }

    override init() {
        self.manager = CLLocationManager()
        super.init()
    }

    func requestWhenInUseAuthorization() { manager.requestWhenInUseAuthorization() }
    func requestAlwaysAuthorization() { manager.requestAlwaysAuthorization() }
    func startMonitoring(for region: CLRegion) { manager.startMonitoring(for: region) }
    func stopMonitoring(for region: CLRegion) { manager.stopMonitoring(for: region) }
}
