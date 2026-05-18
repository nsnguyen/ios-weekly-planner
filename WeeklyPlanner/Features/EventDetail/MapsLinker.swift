import CoreLocation
import UIKit

/// Opens an event's location in Apple Maps. Tries the native `maps://?q=`
/// URL first (which jumps directly into the Maps app), falling back to the
/// `https://maps.apple.com/?q=` universal URL so the call still succeeds if
/// the user has Maps disabled (universal links route through the system).
@MainActor
enum MapsLinker {
    /// Open Apple Maps with the given free-text query (place name or address).
    static func open(query: String) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let native = URL(string: "maps://?q=\(encoded)")
        let universal = URL(string: "https://maps.apple.com/?q=\(encoded)")
        let app = UIApplication.shared
        if let native, app.canOpenURL(native) {
            app.open(native)
        } else if let universal {
            app.open(universal)
        }
    }

    /// Open Apple Maps with explicit coordinates (used when we have a
    /// cached geocode result).
    static func open(coordinate: CLLocationCoordinate2D, label: String) {
        let query = "\(label)@\(coordinate.latitude),\(coordinate.longitude)"
        open(query: query)
    }
}
