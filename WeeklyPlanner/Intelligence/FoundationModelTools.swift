import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)

/// Adapter that wraps a framework-free `PlannerTool` into a Foundation
/// Models `Tool` so the on-device language model can actually call into
/// the planner's stores.
///
/// Each adapter declares its `@Generable` Arguments schema, translates
/// model-friendly inputs (e.g. "0 for today, 1 for tomorrow") into the
/// planner's value types (e.g. a `ClosedRange<Date>`), and shapes the
/// store result as a Codable JSON string the model can read back.
///
/// The whole file is gated `#if canImport(FoundationModels)` so unit
/// tests on the protocol layer don't need the framework imported. All
/// adapters are `@available(iOS 26.0, *)` for the same reason.

private func encodeJSON(_ value: some Encodable, fallback: String) -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(value),
          let text = String(data: data, encoding: .utf8) else {
        return fallback
    }
    return text
}

// MARK: - FindEvents

@available(iOS 26.0, *)
struct FoundationFindEventsTool: Tool {
    let name = "findEvents"
    let description = """
    Find calendar events in the user's planner by date range, category, \
    keyword, or person name. Returns a JSON array of compact event records \
    with stable ids the assistant can cite back.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Days from now to start the search. 0 = today, 1 = tomorrow, -7 = a week ago.")
        let startDayOffset: Int
        @Guide(description: "Days from now to end the search (inclusive). Must be >= startDayOffset.")
        let endDayOffset: Int
        @Guide(description: "Optional category. One of: work, personal, health, family, focus, travel.")
        let category: String?
        @Guide(description: "Optional keyword to match (case-insensitive) anywhere in the event title.")
        let keyword: String?
        @Guide(description: "Optional person name to match (case-insensitive) in the event title.")
        let personName: String?
    }

    private let tool: FindEventsTool
    private let clock: @Sendable () -> Date

    init(tool: FindEventsTool, clock: @escaping @Sendable () -> Date) {
        self.tool = tool
        self.clock = clock
    }

    func call(arguments: Arguments) async throws -> String {
        let now = clock()
        return try await MainActor.run { () -> Task<String, Error> in
            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.date(byAdding: .day, value: arguments.startDayOffset, to: calendar.startOfDay(for: now)) ?? now
            let end = calendar.date(byAdding: .day, value: arguments.endDayOffset + 1, to: calendar.startOfDay(for: now)) ?? now
            let categories = arguments.category.flatMap { Category(rawValue: $0.lowercased()) }.map { [$0] }
            let keywords = arguments.keyword.map { [$0] } ?? []

            let query = EventQuery(
                dateRange: start ... end,
                categories: categories,
                keywords: keywords,
                personName: arguments.personName
            )
            let tool = self.tool
            return Task { @MainActor in
                let results = try await tool.run(query: query)
                return encodeJSON(results, fallback: "[]")
            }
        }.value
    }
}

// MARK: - FindFreeSlots

@available(iOS 26.0, *)
struct FoundationFindFreeSlotsTool: Tool {
    let name = "findFreeSlots"
    let description = """
    Find up to five free time blocks in the user's calendar in a date \
    range. Returns JSON array of { start, end } intervals.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Days from now the search starts.")
        let startDayOffset: Int
        @Guide(description: "Days from now the search ends (inclusive).")
        let endDayOffset: Int
        @Guide(description: "Minimum slot length in minutes (e.g. 30 for a half hour).")
        let minMinutes: Int
        @Guide(description: "Day part to restrict to. One of: morning, afternoon, evening, any.")
        let dayPart: String
    }

    private let tool: FindFreeSlotsTool
    private let clock: @Sendable () -> Date

    init(tool: FindFreeSlotsTool, clock: @escaping @Sendable () -> Date) {
        self.tool = tool
        self.clock = clock
    }

    func call(arguments: Arguments) async throws -> String {
        let now = clock()
        let tool = self.tool
        let dayPart = FindFreeSlotsTool.DayPart(rawValue: arguments.dayPart.lowercased()) ?? .any
        return try await Task { @MainActor in
            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.date(byAdding: .day, value: arguments.startDayOffset, to: calendar.startOfDay(for: now)) ?? now
            let end = calendar.date(byAdding: .day, value: arguments.endDayOffset + 1, to: calendar.startOfDay(for: now)) ?? now
            let slots = try await tool.run(
                dateRange: start ... end,
                minMinutes: arguments.minMinutes,
                dayPart: dayPart
            )
            return encodeJSON(slots, fallback: "[]")
        }.value
    }
}

// MARK: - ScanInbox

@available(iOS 26.0, *)
struct FoundationScanInboxTool: Tool {
    let name = "scanInbox"
    let description = """
    List pending inbox suggestions (events surfaced from email but not \
    yet confirmed). Returns JSON array of compact suggestion records.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Week offset relative to now. 0 = this week, 1 = next week, -1 = last week.")
        let weekOffset: Int
        @Guide(description: "Max number of suggestions to return (e.g. 5).")
        let limit: Int
    }

    private let tool: ScanInboxTool
    private let clock: @Sendable () -> Date

    init(tool: ScanInboxTool, clock: @escaping @Sendable () -> Date) {
        self.tool = tool
        self.clock = clock
    }

    func call(arguments: Arguments) async throws -> String {
        let now = clock()
        let tool = self.tool
        return try await Task { @MainActor in
            let results = try await tool.run(
                weekOffset: arguments.weekOffset,
                today: now,
                limit: arguments.limit
            )
            return encodeJSON(results, fallback: "[]")
        }.value
    }
}

// MARK: - SummarizeWeek

@available(iOS 26.0, *)
struct FoundationSummarizeWeekTool: Tool {
    let name = "summarizeWeek"
    let description = """
    Aggregate the user's week: hours-by-category, tasks done vs open, \
    and up to three highlight event ids. Returns one JSON object.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Week offset relative to now. 0 = this week, 1 = next week, -1 = last week.")
        let weekOffset: Int
    }

    private let tool: SummarizeWeekTool
    private let clock: @Sendable () -> Date

    init(tool: SummarizeWeekTool, clock: @escaping @Sendable () -> Date) {
        self.tool = tool
        self.clock = clock
    }

    func call(arguments: Arguments) async throws -> String {
        let now = clock()
        let tool = self.tool
        return try await Task { @MainActor in
            let summary = try await tool.run(weekOffset: arguments.weekOffset, today: now)
            return encodeJSON(summary, fallback: "{}")
        }.value
    }
}

// MARK: - LastInteraction

@available(iOS 26.0, *)
struct FoundationLastInteractionTool: Tool {
    let name = "lastInteraction"
    let description = """
    Find the most recent event involving a named person in the user's \
    planner (searches event titles and locations in the last eight weeks). \
    Returns one JSON record { eventID, date, context } or an empty object.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Person's first or last name (case-insensitive).")
        let personName: String
    }

    private let tool: LastInteractionTool
    private let clock: @Sendable () -> Date

    init(tool: LastInteractionTool, clock: @escaping @Sendable () -> Date) {
        self.tool = tool
        self.clock = clock
    }

    func call(arguments: Arguments) async throws -> String {
        let now = clock()
        let tool = self.tool
        let personName = arguments.personName
        return try await Task { @MainActor in
            let result = try await tool.run(personName: personName, today: now)
            return encodeJSON(result, fallback: "{}")
        }.value
    }
}

#endif // canImport(FoundationModels)
