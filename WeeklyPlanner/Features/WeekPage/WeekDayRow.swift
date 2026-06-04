import SwiftUI

/// One row of the Hobonichi week page: the weekday tag and oversized date
/// numeral on the left, the day's compact events (or an italic `"none"`
/// placeholder) on the right.
///
/// The week spread is events-only (Phase 30, #26 — permanent default; tasks
/// still render on the Day page). Event-heavy days split into two columns
/// capped with a `"+K more"` affordance per `WeekDayRowLayout` (#25).
///
/// Today's row gets a warm yellow fade behind it; the left column always
/// reads in red ink when `isToday`. Tokens flow in from
/// `@Environment(\.paperTheme)` and `\.paperFont`; the yellow highlight is
/// the only spec-mandated hex literal.
struct WeekDayRow: View {
    /// The day this row represents. Supplies weekday short-name + day number.
    let day: WeekDay

    /// Compact list of events on this day, pre-sorted by start ascending.
    let events: [Event]

    /// Whether this row represents the current calendar day. Drives the
    /// yellow background fade and the red-ink left column.
    let isToday: Bool

    /// Whether to draw the 0.5pt separator under the row content. Callers
    /// pass `false` for the last row in a stack of seven so the page doesn't
    /// pick up a trailing rule under Sunday.
    var showSeparator: Bool = true

    /// Invoked when an event row is tapped. Carries the tapped event's id
    /// so `WeekPageView` can open the `PaperEventSheet`. Defaults to a
    /// no-op so callers that don't wire taps (previews, future test
    /// hosts) don't have to plumb a closure through.
    var onTapEvent: (UUID) -> Void = { _ in }

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                leftColumn
                rightColumn
            }
            .padding(.vertical, 6)
            .frame(minHeight: 56, alignment: .top)
            .background(todayBackground)

            if showSeparator {
                Rectangle()
                    .fill(theme.rule)
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Subviews

    /// 52pt-wide leading column: tracked weekday short-name above an
    /// oversized handwriting date number. Both lines flip to red ink on
    /// the today row.
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(day.weekdayShort.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(isToday ? theme.redInk : theme.ink2)

            Text("\(day.dayNumber)")
                .font(font.font(at: 32, weight: .bold))
                .foregroundStyle(isToday ? theme.redInk : theme.ink)
                .padding(.top, 1)
        }
        .frame(width: 52, alignment: .leading)
    }

    /// Copy shown when a day has no events — Phase 30 (#28) softened this
    /// from a bare em-dash to `"none"`. Static + internal so
    /// `WeekDayRowTests` can pin the wording.
    static let emptyPlaceholder = "none"

    /// Flex right column. Either the day's events laid out per
    /// `WeekDayRowLayout` (single column up to 3, two columns for 4–6,
    /// capped at 5 + `"+K more"` beyond — Phase 30 #25) or the italic
    /// `"none"` placeholder (#28). Tasks never render here (#26).
    @ViewBuilder
    private var rightColumn: some View {
        let layout = WeekDayRowLayout.compute(for: events)
        if layout.isEmpty {
            Text(Self.emptyPlaceholder)
                .font(font.font(at: 16, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if !layout.isTwoColumn {
            eventColumn(layout.leftColumn, overflowCount: 0)
        } else {
            HStack(alignment: .top, spacing: 10) {
                eventColumn(layout.leftColumn, overflowCount: 0)
                eventColumn(layout.rightColumn, overflowCount: layout.overflowCount)
            }
        }
    }

    /// One vertical run of compact event entries; when `overflowCount > 0`
    /// the column ends with the non-interactive `"+K more"` affordance.
    private func eventColumn(_ columnEvents: [Event], overflowCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(columnEvents, id: \.id) { event in
                WeekEventEntry(event: event, onTap: { onTapEvent(event.id) })
            }
            if overflowCount > 0 {
                Text(WeekDayRowLayout.overflowLabel(overflowCount))
                    .font(font.font(at: 13, weight: .regular).italic())
                    .foregroundStyle(theme.ink3)
                    .accessibilityLabel("\(overflowCount) more events")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Warm yellow gradient fade behind the today row. Off-rows return a
    /// transparent rectangle so callers can stack rows uniformly.
    @ViewBuilder
    private var todayBackground: some View {
        if isToday {
            LinearGradient(colors: [
                Color(hex: "#FFE680").opacity(0.4),
                Color(hex: "#FFE680").opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing)
                .cornerRadius(4)
        } else {
            Color.clear
        }
    }
}

// MARK: - WeekDayRowLayout

/// Pure layout decision for a week row's events column (Phase 30, #25).
///
/// Chosen against `docs/mock/paper-planner.jsx`: the mock's week row is a
/// 56pt-min, single-column run with `overflow: hidden` — i.e. it silently
/// clips after ~3 compact event lines. This keeps that 3-line row rhythm
/// (the budget freed by hiding the checklist, #26) but spends the row's
/// horizontal space instead of clipping:
///
/// - 1–3 events → one full-width column (exactly the mock's layout)
/// - 4–6 events → two side-by-side columns, column-major chronological
///   order (read down the left column, then down the right)
/// - 7+ events → the first 5 events plus a `"+K more"` affordance
struct WeekDayRowLayout {
    /// Events rendered in the (always-present-when-non-empty) left column.
    let leftColumn: [Event]

    /// Events rendered in the right column; empty in single-column mode.
    let rightColumn: [Event]

    /// How many events are hidden behind `"+K more"`. 0 when all fit.
    let overflowCount: Int

    /// Max events that render as a single full-width column (the mock's
    /// natural 3-line row height).
    static let singleColumnMax = 3

    /// Visible-event cap once a day overflows two full columns; the sixth
    /// slot goes to the overflow affordance.
    static let overflowVisibleEventCap = 5

    /// The day has no events → the row renders the `"none"` placeholder.
    var isEmpty: Bool { leftColumn.isEmpty }

    /// Whether the row splits into two side-by-side columns.
    var isTwoColumn: Bool { !rightColumn.isEmpty }

    /// Applies the Phase 30 overflow rule to a pre-sorted event list.
    static func compute(for events: [Event]) -> WeekDayRowLayout {
        if events.count <= singleColumnMax {
            return .init(leftColumn: events, rightColumn: [], overflowCount: 0)
        }
        if events.count <= singleColumnMax * 2 {
            let mid = (events.count + 1) / 2
            return .init(leftColumn: Array(events[..<mid]),
                         rightColumn: Array(events[mid...]),
                         overflowCount: 0)
        }
        let visible = events.prefix(overflowVisibleEventCap)
        return .init(leftColumn: Array(visible.prefix(singleColumnMax)),
                     rightColumn: Array(visible.dropFirst(singleColumnMax)),
                     overflowCount: events.count - overflowVisibleEventCap)
    }

    /// `"+K more"` copy for the overflow affordance.
    static func overflowLabel(_ count: Int) -> String { "+\(count) more" }
}

// MARK: - Previews

#Preview("WeekDayRow · Today, overflow, empty") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16
    let satNoon = calendar.date(from: components) ?? Date()
    let days = WeekMath.weekDays(forOffset: 0, today: satNoon)
    let saturday = days[5]

    components.hour = 9
    let nineAM = calendar.date(from: components) ?? satNoon
    let event = Event(title: "Coffee with Dana",
                      start: nineAM,
                      end: calendar.date(byAdding: .hour, value: 1, to: nineAM) ?? nineAM,
                      category: .personal)

    // Seven events on Friday to eyeball the two-column "+K more" rule (#25).
    let categories: [Category] = [.work, .personal, .health, .family, .focus, .work, .personal]
    let friday = days[4]
    let heavy: [Event] = (0..<7).map { i in
        let start = calendar.date(byAdding: .hour, value: i, to: nineAM) ?? nineAM
        return Event(title: "Busy block \(i + 1)",
                     start: start,
                     end: calendar.date(byAdding: .hour, value: 1, to: start) ?? start,
                     category: categories[i])
    }

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 0) {
                    WeekDayRow(day: friday,
                               events: heavy,
                               isToday: false)
                    WeekDayRow(day: saturday,
                               events: [event],
                               isToday: true)
                    WeekDayRow(day: days[6],
                               events: [],
                               isToday: false,
                               showSeparator: false)
                }
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
