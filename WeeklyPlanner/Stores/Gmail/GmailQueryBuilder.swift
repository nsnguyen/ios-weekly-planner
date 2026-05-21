import Foundation

/// Builds the Gmail `q=` query string. v1.0 has a single default; future
/// versions may let the user customize via Settings.
enum GmailQueryBuilder {
    static func defaultQuery(daysBack: Int = 14) -> String {
        let senders = "(from:reservations OR from:tickets OR from:noreply OR from:reception OR from:notifications)"
        let subjects = "subject:(invite OR confirmation OR reservation OR ticket OR appointment OR RSVP OR booking)"
        let excludes = "-category:promotions -category:social"
        return "(\(senders) OR \(subjects)) \(excludes) newer_than:\(daysBack)d"
    }
}
