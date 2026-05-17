import SwiftUI

/// Top-of-page header for the Hobonichi week spread. Renders the week title
/// (`"Week NN"`) and date range on the left, the event / open-task counts on
/// the right, and a 2pt fading underline below the row.
///
/// All design tokens come from `@Environment(\.paperTheme)` and
/// `\.paperFont`. The single hardcoded element is the `"Cochin-Italic"` system
/// serif used for the subtitle — consistent with the Day page header.
struct WeekPageHeader: View {
    /// Metadata for the containing week. Supplies week number + date range.
    let weekMeta: WeekMeta

    /// Calendar year of the week's first day (Monday). Rendered next to the
    /// range in the subtitle, e.g., `"May 11 – 17, 2026"`.
    let year: Int

    /// Total event count for the week. Drives the `"N events"` line.
    let eventCount: Int

    /// Open (i.e., not-done) to-do count for the week. Drives the
    /// `"M tasks left"` line.
    let openTaskCount: Int

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                leftColumn

                Spacer()

                rightColumn
            }
            .padding(EdgeInsets(top: 14, leading: 44, bottom: 4, trailing: 18))

            underline
                .padding(EdgeInsets(top: 6, leading: 44, bottom: 0, trailing: 18))
        }
    }

    // MARK: - Subviews

    /// Title `"Week NN"` plus italic Cochin date-range subtitle.
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Week \(weekMeta.weekNumber)")
                .font(font.font(at: 26, weight: .bold))
                .foregroundStyle(theme.ink)

            Text("\(weekMeta.range), \(year)")
                .font(.custom("Cochin-Italic", size: 12))
                .foregroundStyle(theme.ink2)
        }
    }

    /// Two right-aligned italic count lines.
    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(eventCount) events")
                .font(font.font(at: 15, weight: .regular).italic())
                .foregroundStyle(theme.ink2)

            Text("\(openTaskCount) tasks left")
                .font(font.font(at: 15, weight: .regular).italic())
                .foregroundStyle(theme.ink2)
        }
    }

    /// 2pt-tall horizontal gradient that fades the ink underline out to the
    /// trailing edge. Echoes the `redLine`/rule treatment elsewhere but uses
    /// the primary ink so it reads as a heading separator rather than a
    /// printed rule.
    private var underline: some View {
        LinearGradient(colors: [
            theme.ink.opacity(0.45),
            theme.ink.opacity(0.45),
            theme.ink.opacity(0),
        ],
        startPoint: .leading,
        endPoint: .trailing)
            .frame(height: 2)
    }
}

// MARK: - Previews

#Preview("WeekPageHeader · Cream") {
    let now = WeekPageHeaderPreviewSupport.anchor
    let meta = WeekMath.weekMeta(forOffset: 0, today: now)
    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                WeekPageHeader(weekMeta: meta,
                               year: 2026,
                               eventCount: 7,
                               openTaskCount: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

/// Static support values for the previews so we don't recompute the anchor
/// inside `body` and pollute the view DSL.
private enum WeekPageHeaderPreviewSupport {
    /// Saturday May 16, 2026 at noon — the standard anchor used throughout
    /// the planner test + preview suite.
    static let anchor: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }()
}
