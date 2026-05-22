import SwiftUI

/// One row of the Hobonichi week page: the weekday tag and oversized date
/// numeral on the left, the day's compact events + tasks list (or an italic
/// em-dash placeholder) on the right.
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

    /// Compact list of to-dos on this day, pre-sorted by priority desc then
    /// title asc.
    let tasks: [TaskItem]

    /// Whether this row represents the current calendar day. Drives the
    /// yellow background fade and the red-ink left column.
    let isToday: Bool

    /// Whether to draw the 0.5pt separator under the row content. Callers
    /// pass `false` for the last row in a stack of seven so the page doesn't
    /// pick up a trailing rule under Sunday.
    var showSeparator: Bool = true

    /// Invoked when a task row is tapped. Carries the toggled task's id.
    var onToggleTask: (UUID) -> Void

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
                .font(font.font(at: 28, weight: .bold))
                .foregroundStyle(isToday ? theme.redInk : theme.ink)
                .padding(.top, 1)
        }
        .frame(width: 52, alignment: .leading)
    }

    /// Flex right column. Either the events + tasks stack or an italic
    /// em-dash placeholder when the day is empty.
    @ViewBuilder
    private var rightColumn: some View {
        if events.isEmpty, tasks.isEmpty {
            Text("—")
                .font(font.font(at: 16, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(events, id: \.id) { event in
                    WeekEventEntry(event: event, onTap: { onTapEvent(event.id) })
                }
                ForEach(tasks, id: \.id) { task in
                    WeekTaskEntry(task: task) { onToggleTask(task.id) }
                        .accessibilityIdentifier(AccessibilityIDs.weekpageTodoRow(task.id))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

// MARK: - Previews

#Preview("WeekDayRow · Today with content") {
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
    let task = TaskItem(title: "Buy gift for Sara",
                        due: satNoon,
                        priority: .high,
                        category: .family)

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 0) {
                    WeekDayRow(day: saturday,
                               events: [event],
                               tasks: [task],
                               isToday: true,
                               onToggleTask: { _ in })
                    WeekDayRow(day: days[6],
                               events: [],
                               tasks: [],
                               isToday: false,
                               showSeparator: false,
                               onToggleTask: { _ in })
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
