import SwiftUI

/// Vertical stack of `EventEntryRow`s for a single day. Rows have intrinsic
/// 5pt vertical padding, so the enclosing `LazyVStack` uses `spacing: 0`.
///
/// The caller is responsible for passing `events` already sorted by
/// `event.start` (`DayPageViewModel` does this); the list trusts that order
/// and renders the rows in sequence. `LazyVStack` keeps memory reasonable
/// when a day has many events even though the typical day has under 10.
struct EventEntryList: View {
    /// Events to render, in display order. The view does not re-sort.
    let events: [Event]

    /// Invoked when any row is tapped, passing the tapped event. Defaults
    /// to a no-op so previews and tests can omit it.
    var onTap: (Event) -> Void

    init(events: [Event], onTap: @escaping (Event) -> Void = { _ in }) {
        self.events = events
        self.onTap = onTap
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(events, id: \.id) { event in
                EventEntryRow(event: event) { onTap(event) }
            }
        }
    }
}

// MARK: - Previews

#Preview("EventEntryList · Three events") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16

    components.hour = 9
    components.minute = 0
    let nineAM = calendar.date(from: components) ?? Date()

    components.hour = 11
    components.minute = 30
    let elevenThirty = calendar.date(from: components) ?? Date()

    components.hour = 19
    components.minute = 0
    let sevenPM = calendar.date(from: components) ?? Date()

    let events = [
        Event(title: "Pitch deck review",
              start: nineAM,
              end: calendar.date(byAdding: .hour, value: 1, to: nineAM) ?? nineAM,
              location: "Conf Rm 3",
              category: .work,
              source: .gmail),
        Event(title: "Family brunch",
              start: elevenThirty,
              end: calendar.date(byAdding: .hour, value: 2, to: elevenThirty) ?? elevenThirty,
              location: "Mom's place",
              category: .family),
        Event(title: "Dinner with Mei",
              start: sevenPM,
              end: calendar.date(byAdding: .hour, value: 2, to: sevenPM) ?? sevenPM,
              category: .personal,
              source: .gmail),
    ]

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                EventEntryList(events: events)
                    .padding(.top, 40)
                    .padding(.leading, 44)
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
