import Foundation

@MainActor
final class FindFreeSlotsTool: PlannerTool {
    let name = "findFreeSlots"
    private let store: any EventStoring

    /// Coarse day-part filter so the model can ask for "morning free slots"
    /// without doing date math itself.
    enum DayPart: String, Sendable {
        case morning, afternoon, evening, any
    }

    init(store: any EventStoring) {
        self.store = store
    }

    /// Returns up to five free slots inside `dateRange` at least
    /// `minMinutes` long. Slot search is greedy left-to-right against the
    /// occupied intervals of every event in the range.
    func run(
        dateRange: ClosedRange<Date>,
        minMinutes: Int,
        dayPart: DayPart
    ) async throws -> [ToolFreeSlot] {
        let query = EventQuery(
            dateRange: dateRange,
            categories: nil,
            keywords: [],
            personName: nil
        )
        let events = (try? await store.events(matching: query)) ?? []
        let busy = events.map { ($0.start, $0.end) }.sorted { $0.0 < $1.0 }

        var free: [ToolFreeSlot] = []
        var cursor = dateRange.lowerBound
        for (start, end) in busy {
            if start > cursor {
                appendIfLongEnough(start: cursor, end: min(start, dateRange.upperBound),
                                   minMinutes: minMinutes, dayPart: dayPart, into: &free)
                if free.count >= 5 { return free }
            }
            cursor = max(cursor, end)
            if cursor >= dateRange.upperBound { break }
        }
        if cursor < dateRange.upperBound {
            appendIfLongEnough(start: cursor, end: dateRange.upperBound,
                               minMinutes: minMinutes, dayPart: dayPart, into: &free)
        }
        return Array(free.prefix(5))
    }

    private func appendIfLongEnough(
        start: Date,
        end: Date,
        minMinutes: Int,
        dayPart: DayPart,
        into free: inout [ToolFreeSlot]
    ) {
        guard end > start else { return }
        guard end.timeIntervalSince(start) >= Double(minMinutes) * 60 else { return }
        guard Self.matches(dayPart: dayPart, start: start) else { return }
        free.append(ToolFreeSlot(start: start, end: end))
    }

    private static func matches(dayPart: DayPart, start: Date) -> Bool {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: start)
        switch dayPart {
        case .morning: return hour < 12
        case .afternoon: return hour >= 12 && hour < 17
        case .evening: return hour >= 17
        case .any: return true
        }
    }
}
