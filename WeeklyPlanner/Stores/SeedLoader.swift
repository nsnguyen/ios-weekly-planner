import Foundation
import SwiftData

/// Loads bundled JSON seed data into an empty SwiftData container.
/// Only runs in `#if DEBUG` builds — production starts empty so the user
/// imports their own data via EventKit (Phase 04) and Gmail (Phase 18).
///
/// The seed JSON files in `Resources/SeedData/` are empty placeholders in
/// Phase 03. Phase 06 (Day Page) is the first phase that needs real seed
/// content for SwiftUI Previews; it will populate them from
/// `docs/mock/data.jsx` then.
enum SeedLoader {
    /// Seeds the container if it is empty. No-op otherwise.
    @MainActor
    static func seedIfEmpty(context: ModelContext) {
        #if DEBUG
            guard isEmpty(context: context) else { return }
            loadEvents(context: context)
            loadTasks(context: context)
            loadInbox(context: context)
            loadInsights(context: context)
            try? context.save()
        #endif
    }

    @MainActor
    private static func isEmpty(context: ModelContext) -> Bool {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return events.isEmpty && tasks.isEmpty
    }

    @MainActor
    private static func loadEvents(context: ModelContext) {
        for offset in [-1, 0, 1, 2] {
            let suffix = offset >= 0 ? "\(offset)" : "-\(abs(offset))"
            guard
                let url = Bundle.main.url(forResource: "seed-week-\(suffix)", withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let array = try? JSONDecoder.iso8601.decode([SeedEvent].self, from: data)
            else { continue }
            for seed in array {
                context.insert(seed.toEvent())
            }
        }
    }

    @MainActor
    private static func loadTasks(context: ModelContext) {
        guard
            let url = Bundle.main.url(forResource: "seed-tasks", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let array = try? JSONDecoder.iso8601.decode([SeedTask].self, from: data)
        else { return }
        for seed in array {
            context.insert(seed.toTaskItem())
        }
    }

    @MainActor
    private static func loadInbox(context: ModelContext) {
        guard
            let url = Bundle.main.url(forResource: "seed-inbox", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let array = try? JSONDecoder.iso8601.decode([SeedInbox].self, from: data)
        else { return }
        for seed in array {
            context.insert(seed.toInboxSuggestion())
        }
    }

    @MainActor
    private static func loadInsights(context: ModelContext) {
        guard
            let url = Bundle.main.url(forResource: "seed-insights", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let array = try? JSONDecoder.iso8601.decode([SeedInsight].self, from: data)
        else { return }
        for seed in array {
            context.insert(seed.toInsight())
        }
    }
}

// MARK: - JSON DTOs

private struct SeedEvent: Decodable {
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let category: Category
    let attendeesCount: Int?
    let source: EventSource?

    func toEvent() -> Event {
        Event(title: title,
              start: start,
              end: end,
              location: location,
              category: category,
              attendeesCount: attendeesCount ?? 0,
              source: source ?? .manual)
    }
}

private struct SeedTask: Decodable {
    let title: String
    let due: Date
    let done: Bool?
    let priority: Priority?
    let category: Category
    let reminderText: String?

    func toTaskItem() -> TaskItem {
        TaskItem(title: title,
                 due: due,
                 done: done ?? false,
                 priority: priority ?? .med,
                 category: category,
                 reminderText: reminderText)
    }
}

private struct SeedInbox: Decodable {
    let gmailMessageID: String
    let proposedStart: Date
    let proposedEnd: Date?
    let title: String
    let fromName: String
    let fromEmail: String
    let category: Category
    let subject: String
    let bodySnippet: String?

    func toInboxSuggestion() -> InboxSuggestion {
        InboxSuggestion(gmailMessageID: gmailMessageID,
                        proposedStart: proposedStart,
                        proposedEnd: proposedEnd,
                        title: title,
                        fromName: fromName,
                        fromEmail: fromEmail,
                        category: category,
                        subject: subject,
                        bodySnippet: bodySnippet)
    }
}

private struct SeedInsight: Decodable {
    let dayKey: String
    let text: String
    let colorHex: String?
    let tiltDegrees: Double?

    func toInsight() -> AIInsight {
        AIInsight(dayKey: dayKey,
                  text: text,
                  colorHex: colorHex ?? "#FFE680",
                  tiltDegrees: tiltDegrees ?? 0)
    }
}

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
