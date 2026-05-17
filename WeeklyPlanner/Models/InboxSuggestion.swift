import Foundation
import SwiftData

/// A pending event suggestion sourced from the user's Gmail inbox.
/// Created by Phase 18's inbox pipeline; surfaced as the "Suggested" rows on
/// the day page. The user accepts (turning it into an `Event`) or dismisses.
@Model
final class InboxSuggestion {
    @Attribute(.unique) var id: UUID

    /// Gmail RFC-822 Message-Id. Unique across the user's inbox.
    @Attribute(.unique) var gmailMessageID: String

    var proposedStart: Date
    var proposedEnd: Date?

    var title: String
    var fromName: String
    var fromEmail: String

    var categoryRaw: String

    var subject: String
    /// First ~280 chars of the message body; full body is fetched on demand.
    var bodySnippet: String?

    var statusRaw: String
    var createdAt: Date

    init(id: UUID = UUID(),
         gmailMessageID: String,
         proposedStart: Date,
         proposedEnd: Date? = nil,
         title: String,
         fromName: String,
         fromEmail: String,
         category: Category = .personal,
         subject: String,
         bodySnippet: String? = nil,
         status: InboxStatus = .pending,
         createdAt: Date = .init())
    {
        self.id = id
        self.gmailMessageID = gmailMessageID
        self.proposedStart = proposedStart
        self.proposedEnd = proposedEnd
        self.title = title
        self.fromName = fromName
        self.fromEmail = fromEmail
        categoryRaw = category.rawValue
        self.subject = subject
        self.bodySnippet = bodySnippet
        statusRaw = status.rawValue
        self.createdAt = createdAt
    }
}

extension InboxSuggestion {
    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var status: InboxStatus {
        get { InboxStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
