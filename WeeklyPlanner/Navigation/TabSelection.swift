import Foundation
import Observation

/// The three destinations on the bottom paper tab bar. Raw values double as
/// the persisted-form string in `UserSettings.lastTabRaw`.
enum Tab: String, CaseIterable, Hashable, Sendable {
    case calendar
    case review
    case settings
}

/// Source-of-truth for the active tab. Loads from `SettingsStoring` on init
/// and writes back on every mutation of `current`. Stays `@MainActor`-only
/// because mutating SwiftData via the settings store must happen on the main
/// context.
@MainActor
@Observable
final class TabSelection {
    /// The currently-visible tab. Writing this triggers a `SettingsStoring.update`
    /// so the choice survives launches.
    var current: Tab {
        didSet {
            guard oldValue != current else { return }
            try? settings.update { $0.lastTabRaw = current.rawValue }
        }
    }

    private let settings: any SettingsStoring

    init(settings: any SettingsStoring) {
        self.settings = settings
        let raw = (try? settings.current().lastTabRaw) ?? Tab.calendar.rawValue
        current = Tab(rawValue: raw) ?? .calendar
    }
}
