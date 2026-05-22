import SwiftUI

/// One row in the Day page's events list. Two-column layout: a fixed-width
/// time gutter on the leading edge (Cochin tabular numerals so 9 AM and
/// 12:30 PM line up) plus a right column that stacks the handwritten title
/// (with category dot and optional Gmail glyph) over an italic location
/// subtitle when present.
///
/// All visual tokens come from `@Environment(\.paperTheme/.paperFont/.paperSize)`
/// — no hex literals here. Tap handling is forwarded through the optional
/// `onTap` closure; the whole row is wrapped in a `.plain`-styled `Button` so
/// the row is fully hit-testable without picking up the system tint.
struct EventEntryRow: View {
    /// The event this row represents.
    let event: Event

    /// Invoked when the row is tapped. The Day page wires this to the
    /// event-detail sheet in Phase 11; for now it is optional so previews
    /// and tests can pass `nil`.
    var onTap: (() -> Void)?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
    @Environment(\.dynamicTypeSize) private var dtSize

    init(event: Event, onTap: (() -> Void)? = nil) {
        self.event = event
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                timeGutter
                rightColumn
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    /// Leading column showing the start-time label in Cochin. Width widens
    /// from 48pt to 64pt at AX2+ so larger numerals don't crowd events.
    private var timeGutter: some View {
        Text(Self.timeLabel(for: event.start))
            .font(.custom("Cochin", size: 13).weight(.semibold).monospacedDigit())
            .foregroundStyle(theme.ink2)
            .frame(width: DynamicTypeLayout.timeGutterWidth(at: dtSize), alignment: .leading)
    }

    /// Right column: title row plus optional location subtitle below.
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow

            if let location = event.location {
                locationRow(location)
            }
        }
    }

    /// Title + 9pt category dot + optional Gmail glyph, baseline-aligned.
    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(event.title)
                .font(font.font(at: 21 * size.scale, weight: .semibold))
                .tracking(0.1)
                .foregroundStyle(CategoryPalette.inkColor(event.category, in: theme))

            Circle()
                .fill(CategoryPalette.dot(event.category))
                .opacity(0.7)
                .frame(width: 9, height: 9)

            if event.source == .gmail {
                GmailGlyph(size: 10)
            }
        }
    }

    /// Italic Cochin location subtitle, indented 8pt inside the right column
    /// so it lands 56pt from the row's outer leading edge — aligned under the
    /// title rather than the time gutter.
    private func locationRow(_ location: String) -> some View {
        Text("\u{21B3} \(location)")
            .font(.custom("Cochin-Italic", size: 12))
            .foregroundStyle(theme.ink2)
            .padding(.leading, 8)
            .padding(.top, -2)
    }

    // MARK: - Time formatting

    /// Formats `date` as `"9 AM"`, `"12 PM"`, `"7:45 AM"`, etc. — hour-only
    /// when the minute component is zero, otherwise `h:mm a`. No leading zero
    /// on the hour; AM/PM uppercased via `en_US_POSIX`.
    ///
    /// Internal (not private) so `EventEntryRowTests` can exercise the
    /// formatting rules without going through the view layer.
    static func timeLabel(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let minute = calendar.component(.minute, from: date)
        let formatter = minute == 0 ? hourOnlyFormatter : hourMinuteFormatter
        return formatter.string(from: date)
    }

    /// `"9 AM"`, `"12 PM"` — used when the start time is exactly on the hour.
    private static let hourOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// `"7:45 AM"`, `"1:30 PM"` — used when the start time has non-zero minutes.
    private static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Previews

#Preview("EventEntryRow · Two rows") {
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
                           location: "Conf Rm 3",
                           category: .work,
                           source: .gmail)

    let manualEvent = Event(title: "Deep work",
                            start: oneThirtyPM,
                            end: calendar.date(byAdding: .hour, value: 2, to: oneThirtyPM) ?? oneThirtyPM,
                            category: .focus)

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 0) {
                    EventEntryRow(event: gmailEvent)
                    EventEntryRow(event: manualEvent)
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
