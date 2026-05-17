import CoreLocation
import Foundation

/// A geofenced location used by "when I arrive" reminders. The geofence is
/// realised as an `EKAlarm(structuredLocation:)` with `proximity = .enter`
/// in Phase 04, and as a `CLCircularRegion` for local notifications in
/// Phase 19.
struct LocationReminder: Codable, Equatable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
    /// Radius in meters. Apple recommends ≥ 100 m for reliable triggering.
    let radiusMeters: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
