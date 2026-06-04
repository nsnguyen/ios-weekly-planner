import SwiftUI

/// Top-of-page header for the Hobonichi week spread. Renders the week's date
/// range as the single enlarged title (Phase 30, #30 — the `"Week NN"` label
/// and the right-hand `"N events"` / `"M tasks left"` count lines are gone,
/// #29) above a 2pt fading underline.
///
/// All design tokens come from `@Environment(\.paperTheme)` and
/// `\.paperFont`.
struct WeekPageHeader: View {
    /// Metadata for the containing week. Supplies the date range.
    let weekMeta: WeekMeta

    /// Calendar year of the week's first day (Monday). Rendered after the
    /// range in the title, e.g., `"May 11 – 17, 2026"`.
    let year: Int

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.title(weekMeta: weekMeta, year: year))
                .font(font.font(at: 30, weight: .bold))
                .foregroundStyle(theme.ink)
                .padding(EdgeInsets(top: 14, leading: 44, bottom: 4, trailing: 18))

            underline
                .padding(EdgeInsets(top: 6, leading: 44, bottom: 0, trailing: 18))
        }
    }

    // MARK: - Title

    /// The header's single line of copy — the week's date range plus year,
    /// e.g. `"May 11 – 17, 2026"`. Static + internal so
    /// `WeekPageHeaderTests` can pin the no-"Week"/no-counts contract
    /// without view introspection (Phase 30, #29 + #30).
    static func title(weekMeta: WeekMeta, year: Int) -> String {
        "\(weekMeta.range), \(year)"
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
                WeekPageHeader(weekMeta: meta, year: 2026)
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
