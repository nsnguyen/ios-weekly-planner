import Foundation
import UserNotifications
import os

/// Reads `event.reminders` and emits stable-identifier `UNNotificationRequest`s.
///
/// Identifier shape — predictable on purpose so the rescheduling observer can
/// clear them with `removePending(withIdentifiers:)` without keeping any side
/// state:
///   - `event-{uuid}-time-{minutes}` — `UNCalendarNotificationTrigger`
///   - `event-{uuid}-arrive`         — `UNLocationNotificationTrigger`
///                                     (registered by `LocationRegistering`)
@MainActor
final class EventNotificationScheduler {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    /// Recurring series schedule only this far ahead; the Phase 19
    /// rescheduling observer rolls the window forward on every event
    /// change / app activation.
    static let recurringWindowDays = 30
    static let recurringMaxOccurrences = 8

    private let center: any NotificationCentering
    private let locationRegistrar: any LocationRegistering
    private let eventStore: (any EventStoring)?

    init(center: any NotificationCentering,
         locationRegistrar: any LocationRegistering,
         eventStore: (any EventStoring)? = nil)
    {
        self.center = center
        self.locationRegistrar = locationRegistrar
        self.eventStore = eventStore
    }

    /// Clears any existing notifications for this event and re-schedules from
    /// its current `reminders`. Idempotent.
    func schedule(event: Event) async throws {
        let prefix = "event-\(event.id.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
            Self.log.info("Cleared \(toRemove.count) pending requests for event \(event.id, privacy: .public)")
        }
        locationRegistrar.unregister(eventID: event.id)

        if let recurrence = event.recurrence {
            let calendar = WeekMath.mondayCalendar()
            let now = Date()
            let windowEnd = calendar.date(byAdding: .day, value: Self.recurringWindowDays, to: now) ?? now
            let starts = OccurrenceExpander.occurrenceStarts(
                seriesStart: event.start,
                recurrence: recurrence,
                in: now ..< windowEnd,
                excluding: event.excludedOccurrenceStarts,
                calendar: calendar)
                .prefix(Self.recurringMaxOccurrences)

            for start in starts {
                for reminder in event.reminders {
                    do {
                        switch reminder {
                        case let .timeBefore(minutes):
                            try await scheduleTime(event: event,
                                                   occurrenceStart: start,
                                                   minutesBefore: minutes,
                                                   occurrenceSuffix: "occ-\(Int(start.timeIntervalSince1970))-")
                        case .onArrive:
                            break // Location reminders are not per-occurrence.
                        }
                    } catch {
                        Self.log.error("Recurring schedule failed: \(String(describing: error))")
                    }
                }
            }
            // Location reminders register once for the series.
            for reminder in event.reminders {
                if case let .onArrive(location) = reminder {
                    scheduleArrival(event: event, reminder: location)
                }
            }
            return
        }

        for reminder in event.reminders {
            do {
                switch reminder {
                case let .timeBefore(minutes):
                    try await scheduleTime(event: event, occurrenceStart: event.start, minutesBefore: minutes)
                case let .onArrive(location):
                    scheduleArrival(event: event, reminder: location)
                }
            } catch {
                Self.log.error("Schedule failed for event \(event.id, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Removes every notification request for this event id and any registered
    /// region.
    func cancel(eventID: UUID) async {
        let prefix = "event-\(eventID.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
        }
        locationRegistrar.unregister(eventID: eventID)
    }

    /// Re-schedules every event whose start is inside `window`. Called after a
    /// notification-authorization grant and on the future manual-add flow.
    func rescheduleAll(in window: ClosedRange<Date>) async {
        guard let store = eventStore else {
            Self.log.error("rescheduleAll called without an EventStoring — no-op")
            return
        }
        // Compute a coarse week range bracketing the window.
        let now = Date()
        let startOffset = Self.weekOffset(from: window.lowerBound, today: now)
        let endOffset = Self.weekOffset(from: window.upperBound, today: now)
        var events: [Event] = []
        for offset in startOffset...endOffset {
            do {
                let weekEvents = try await store.events(forWeekOffset: offset, today: now)
                events.append(contentsOf: weekEvents)
            } catch {
                Self.log.error("rescheduleAll fetch failed for offset \(offset, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        for event in events where window.contains(event.start) {
            do { try await schedule(event: event) }
            catch { Self.log.error("rescheduleAll schedule failed: \(String(describing: error), privacy: .public)") }
        }
    }

    // MARK: - Private

    /// Schedules one time-based reminder for `occurrenceStart`. Single events
    /// pass `occurrenceStart: event.start` with the default empty suffix, which
    /// reproduces the exact Phase 19 identifier `event-<id>-time-<min>`.
    /// Recurring occurrences pass a distinct `occurrenceSuffix` so each
    /// instance gets its own request under the same event prefix.
    private func scheduleTime(event: Event,
                              occurrenceStart: Date,
                              minutesBefore: Int,
                              occurrenceSuffix: String = "") async throws
    {
        let fireDate = occurrenceStart.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard fireDate > Date() else { return }   // Past — silently skip.

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                         from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let content = NotificationContentBuilder.timeBased(
            title: event.title,
            startsAt: occurrenceStart,
            location: event.location,
            minutesBefore: minutesBefore
        )
        content.userInfo = ["event.id": event.id.uuidString]

        let id = "event-\(event.id.uuidString)-\(occurrenceSuffix)time-\(minutesBefore)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(request)
        Self.log.info("Scheduled event-time \(id, privacy: .public) for \(fireDate, privacy: .public)")
    }

    private func scheduleArrival(event: Event, reminder: LocationReminder) {
        let proximity = max(0, Calendar.current.dateComponents([.day], from: Date(), to: event.start).day ?? 0)
        let identifier = "event-\(event.id.uuidString)-arrive"
        let title = event.title
        let location = event.location
        _ = locationRegistrar.register(
            eventID: event.id,
            reminder: reminder,
            content: {
                let content = NotificationContentBuilder.locationBased(title: title, locationName: reminder.name)
                if let location { content.subtitle = location }
                content.userInfo = ["event.id": event.id.uuidString]
                return content
            },
            proximityInDays: proximity
        )
        Self.log.info("Registered arrival region \(identifier, privacy: .public) proximityDays=\(proximity, privacy: .public)")
    }

    /// Crude Monday-based week offset from `today` to `date`. Mirrors
    /// `SwiftDataEventStore.weekBounds` semantics; suitable for selecting the
    /// fetch window.
    private static func weekOffset(from date: Date, today: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.weekOfYear], from: today, to: date)
        return comps.weekOfYear ?? 0
    }
}
