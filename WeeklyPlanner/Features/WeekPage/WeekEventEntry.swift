import SwiftUI

/// Compact one-line event row used inside a `WeekDayRow`. Mirrors the larger
/// `EventEntryRow` but trims the time gutter to 36pt, drops the location
/// subtitle, and renders the title in a single ellipsized line with a
/// trailing category dot on the right.
///
/// Like `EventEntryRow`, all colors and the handwriting font flow from
/// `@Environment(\.paperTheme)` / `\.paperFont`. The time gutter uses Cochin
/// to keep the digits readable at 10pt; the AM/PM gap is stripped (e.g.
/// `"9AM"`, `"1:30PM"`) so the column lines up tightly.
struct WeekEventEntry: View {
    /// The event this row represents.
    let event: Event

    /// Invoked when the row is tapped. The Week page wires this to the
    /// event-detail sheet via `openEventID`; defaults to a no-op so
    /// previews and unit tests can omit it.
    var onTap: () -> Void = {}

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                timeColumn
                titleColumn
                trailingDot
            }
            .padding(.bottom, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    /// 36pt-wide leading column showing the start-time label in tabular Cochin.
    private var timeColumn: some View {
        Text(Self.compactTime(event.start))
            .font(.custom("Cochin", size: 10).monospacedDigit())
            .foregroundStyle(theme.ink2)
            .frame(width: 36, alignment: .leading)
    }

    /// Flex title column: handwriting title in the category ink color, plus
    /// an inline Gmail glyph when the event came from the inbox pipeline.
    /// `.lineLimit(1)` + `.truncationMode(.tail)` so long titles ellipsize
    /// instead of pushing the trailing dot off-row.
    private var titleColumn: some View {
        HStack(spacing: 4) {
            Text(event.title)
                .font(font.font(at: 15, weight: .regular))
                .foregroundStyle(CategoryPalette.inkColor(event.category, in: theme))
                .lineLimit(1)
                .truncationMode(.tail)

            if event.source == .gmail {
                GmailGlyph(size: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 6×6 category dot, 75% opacity. Sits flush on the trailing edge of the
    /// row as a visual cue to the category color.
    private var trailingDot: some View {
        Circle()
            .fill(CategoryPalette.dot(event.category))
            .opacity(0.75)
            .frame(width: 6, height: 6)
    }

    // MARK: - Time formatting

    /// Formats `date` as `"9AM"` / `"1:30PM"` — same rules as
    /// `EventEntryRow.timeLabel`, but the space between hour and AM/PM is
    /// stripped so the 36pt column reads tighter. Hour-only when the minute
    /// component is zero, otherwise `h:mma`.
    ///
    /// Internal (not private) so a future `WeekEventEntryTests` can exercise
    /// the formatting rules without going through the view layer.
    static func compactTime(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let minute = calendar.component(.minute, from: date)
        let formatter = minute == 0 ? hourOnlyFormatter : hourMinuteFormatter
        return formatter.string(from: date)
    }

    /// `"9AM"`, `"12PM"` — used when the start time is exactly on the hour.
    private static let hourOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// `"7:45AM"`, `"1:30PM"` — used when the start time has non-zero minutes.
    private static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Previews

#Preview("WeekEventEntry · Two rows") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16

    components.hour = 9
    components.minute = 0
    let nineAM = calendar.date(from: components) ?? Date()

    components.hour = 13
    components.minute = 30
    let oneThirtyPM = calendar.date(from: components) ?? Date()

    let gmailEvent = Event(title: "Pitch deck review",
                           start: nineAM,
                           end: calendar.date(byAdding: .hour, value: 1, to: nineAM) ?? nineAM,
                           category: .work,
                           source: .gmail)

    let manualEvent = Event(title: "Deep work block",
                            start: oneThirtyPM,
                            end: calendar.date(byAdding: .hour, value: 2, to: oneThirtyPM) ?? oneThirtyPM,
                            category: .focus)

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 0) {
                    WeekEventEntry(event: gmailEvent)
                    WeekEventEntry(event: manualEvent)
                }
                .padding(.top, 40)
                .padding(.leading, 60)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
