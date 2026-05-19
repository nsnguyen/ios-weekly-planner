import Foundation

/// Top-level visual style. `.paper` is the leather-book aesthetic (default);
/// `.modern` is the stock-iOS fallback theme rendered by Phase 20.
enum AppStyle: String, CaseIterable, Hashable, Codable {
    case paper
    case modern
}

/// Which day-spread the user is on inside `.paper` style.
enum PaperView: String, CaseIterable, Hashable, Codable {
    case day
    case week
    case review
}

/// Which spread the user is on inside `.modern` style.
enum ModernView: String, CaseIterable, Hashable, Codable {
    case day
    case twoDay
    case week
}

/// State of an inbox-sourced event suggestion.
enum InboxStatus: String, CaseIterable, Hashable, Codable {
    case pending
    case accepted
    case dismissed
}
