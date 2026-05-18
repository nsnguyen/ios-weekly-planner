import Foundation

/// Snapshot of whether the on-device Foundation Models pipeline is ready to
/// answer a query. Computed by `IntelligenceService.availability()` at every
/// call site so a long-running session reacts to Settings toggles, model
/// downloads, and thermal state changes without restart.
enum AvailabilityState: Hashable {
    case available
    case unavailable(Reason)

    enum Reason: Hashable {
        /// Hardware can't run Apple Intelligence (older device).
        case deviceNotEligible
        /// Model files are still downloading or warming up.
        case modelNotReady
        /// User hasn't enabled Apple Intelligence in iOS Settings.
        case appleIntelligenceNotEnabled
        /// User flipped the planner's own AI toggle off (UserSettings).
        case userDisabled
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// Single short string shown in the AI overlay footer when we fall back.
    var fallbackMessage: String {
        switch self {
        case .available:
            return ""
        case .unavailable(.deviceNotEligible):
            return "Apple Intelligence is unavailable on this device. Showing canned suggestions."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is warming up. Showing canned suggestions."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Enable Apple Intelligence in Settings to get personalized answers. Showing canned suggestions."
        case .unavailable(.userDisabled):
            return "Apple Intelligence is turned off in Settings. Showing canned suggestions."
        }
    }
}
