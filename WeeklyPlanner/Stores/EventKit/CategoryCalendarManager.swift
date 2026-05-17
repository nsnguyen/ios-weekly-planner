import EventKit
import SwiftUI
import UIKit

/// Owns the six "Planner — X" calendars that we use to back our six event
/// categories. Created lazily on first call to `ensureCalendars()` (which
/// runs after the user grants Calendar access).
///
/// The mapping (`[Category: EKCalendar.calendarIdentifier]`) is persisted on
/// `UserSettings.accentHex` adjacent fields — Phase 16 wires it in. For now,
/// the manager looks calendars up by title on every call.
@MainActor
final class CategoryCalendarManager {
    private let gateway: any EventKitGateway

    init(gateway: any EventKitGateway) {
        self.gateway = gateway
    }

    /// Ensures every category has a backing EKCalendar. Creates missing ones
    /// against `gateway.preferredSource`. Returns the resolved map.
    @discardableResult
    func ensureCalendars() throws -> [Category: EKCalendar] {
        var resolved: [Category: EKCalendar] = [:]
        for category in Category.allCases {
            if let existing = findCalendar(for: category) {
                resolved[category] = existing
                continue
            }
            let created = try createCalendar(for: category)
            resolved[category] = created
        }
        return resolved
    }

    /// Looks up an existing calendar by title without creating anything.
    func findCalendar(for category: Category) -> EKCalendar? {
        let target = title(for: category)
        return gateway.eventCalendars.first { $0.title == target }
    }

    /// Convenience: which `Category` does an `EKCalendar` belong to, based
    /// on title? `nil` if the calendar is a third-party / system one.
    static func category(for calendar: EKCalendar) -> Category? {
        Category.allCases.first { title(for: $0) == calendar.title }
    }

    // MARK: - Internals

    private func createCalendar(for category: Category) throws -> EKCalendar {
        let calendar = gateway.newCalendar(for: .event, source: gateway.preferredSource)
        calendar.title = Self.title(for: category)
        calendar.cgColor = uiColor(for: category).cgColor
        try gateway.saveCalendar(calendar)
        return calendar
    }

    static func title(for category: Category) -> String {
        "Planner — \(CategoryPalette.displayName(category))"
    }

    private func title(for category: Category) -> String {
        Self.title(for: category)
    }

    private func uiColor(for category: Category) -> UIColor {
        UIColor(CategoryPalette.dot(category))
    }
}
