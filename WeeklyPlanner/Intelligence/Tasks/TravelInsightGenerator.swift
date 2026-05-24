import Foundation
import CoreLocation
import MapKit

/// Seam over MapKit / CoreLocation so unit tests don't need the real
/// frameworks. Production impl below wraps `CLLocationManager` +
/// `CLGeocoder` + `MKDirections`.
@MainActor
protocol TravelProviding {
    func locationAuthorizationStatus() -> CLAuthorizationStatus
    func currentLocation() async -> CLLocation?
    func geocode(address: String) async -> CLLocationCoordinate2D?
    func travelTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> TimeInterval?
}

/// Emits "Leave by HH:mm for <event>" for the nearest event with a
/// location that's starting within 4 hours, when the recommended
/// departure time falls inside the next 60 minutes. Returns `nil` when
/// location auth isn't granted, the event has no location, or any of
/// the MapKit hops fails.
///
/// Priority `0` puts travel at the top of the cascade — it's the most
/// time-sensitive nudge.
@MainActor
final class TravelInsightGenerator: InsightGenerator {
    let kind: InsightKind = .travel

    private let provider: any TravelProviding
    private let bufferSeconds: TimeInterval
    private let windowSeconds: TimeInterval
    private let eventLookaheadSeconds: TimeInterval

    /// - Parameters:
    ///   - provider: Injected MapKit/CoreLocation seam.
    ///   - bufferSeconds: Extra cushion before recommended departure
    ///     (default 5 minutes — gives the user time to grab keys).
    ///   - windowSeconds: How far ahead to surface a sticky. Departure
    ///     must fall in `(0, windowSeconds]` from `now`.
    ///   - eventLookaheadSeconds: Don't consider events past this
    ///     horizon (default 4 hours).
    init(provider: any TravelProviding,
         bufferSeconds: TimeInterval = 5 * 60,
         windowSeconds: TimeInterval = 60 * 60,
         eventLookaheadSeconds: TimeInterval = 4 * 3600)
    {
        self.provider = provider
        self.bufferSeconds = bufferSeconds
        self.windowSeconds = windowSeconds
        self.eventLookaheadSeconds = eventLookaheadSeconds
    }

    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    func generate(for day: DayContext) async -> AIInsight? {
        let status = provider.locationAuthorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }

        let now = day.now
        let cutoff = now.addingTimeInterval(eventLookaheadSeconds)

        // Sort events by start so we always pick the nearest qualifying
        // one. Filter to those with a location, starting in the future,
        // within the lookahead horizon.
        let candidates = day.events
            .filter { $0.location != nil && $0.start > now && $0.start <= cutoff }
            .sorted { $0.start < $1.start }

        guard let here = await provider.currentLocation() else { return nil }

        for event in candidates {
            guard let address = event.location,
                  let coord = await provider.geocode(address: address),
                  let travelTime = await provider.travelTime(
                      from: here.coordinate, to: coord)
            else { continue }

            let departureBy = event.start.addingTimeInterval(-travelTime - bufferSeconds)
            let secondsUntilDeparture = departureBy.timeIntervalSince(now)
            guard secondsUntilDeparture > 0, secondsUntilDeparture <= windowSeconds else {
                continue
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let timeString = formatter.string(from: departureBy)

            return AIInsight(
                dayKey: day.dayKey,
                dateGenerated: now,
                text: "Leave by \(timeString) for \(event.title)",
                colorHex: InsightKind.travel.colorHex,
                tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                kind: .travel,
                actionURL: "http://maps.apple.com/?daddr=\(coord.latitude),\(coord.longitude)&dirflg=d",
                priority: InsightKind.travel.defaultPriority
            )
        }

        return nil
    }
}

// MARK: - Live MapKit / CoreLocation provider

/// Production `TravelProviding` impl. Wraps `CLLocationManager` (one-shot
/// authorization check + current location), `CLGeocoder` (address →
/// coordinate), and `MKDirections` (coordinate pair → travel time).
@MainActor
final class LiveTravelProvider: NSObject, TravelProviding {
    private let manager: CLLocationManager

    override init() {
        self.manager = CLLocationManager()
        super.init()
    }

    func locationAuthorizationStatus() -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func currentLocation() async -> CLLocation? {
        // One-shot location request via the async-friendly Combine bridge
        // pattern. For Phase 24 v1 we just read `manager.location` (cached
        // value from the system); if `nil`, return nil and let the
        // generator skip. Real "request fresh location" would need a
        // CLLocationManagerDelegate hop — out of scope.
        manager.location
    }

    func geocode(address: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    func travelTime(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D) async -> TimeInterval?
    {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            return response.routes.first?.expectedTravelTime
        } catch {
            return nil
        }
    }
}
