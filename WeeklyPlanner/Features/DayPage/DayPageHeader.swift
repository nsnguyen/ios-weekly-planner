import SwiftUI

/// Two-column header at the top of a Day page: weekday name + caption on the
/// left, oversized rotated date numeral on the right. If the page represents
/// the current calendar day, a live-updating `TodayChip` is rendered beneath
/// the row.
///
/// The component reads its design tokens from the environment — `paperTheme`
/// for ink colors, `paperFont` for the handwriting family, and `paperSize`
/// for the S/M/L scale step — so it adapts to user settings without any
/// per-call configuration. Numeric values come from the `Typography` ramp
/// (`pageWeekdayTitle`, `pageDateNumber`, `pageMonthCaption`).
struct DayPageHeader: View {
    /// The day this header represents. Supplies the weekday name, day number,
    /// and month-short string.
    let weekDay: WeekDay

    /// Metadata for the containing week. Used for the "Week NN" caption.
    let weekMeta: WeekMeta

    /// Drives the date-number tint (red when today) and the visibility of the
    /// `TodayChip` underneath the row.
    let isToday: Bool

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekDay.weekdayLong)
                        .font(font.font(at: 30 * size.scale, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .tracking(-0.5)

                    Text(Self.caption(for: weekDay))
                        .font(.custom("Cochin-Italic", size: 12))
                        .foregroundStyle(theme.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DayPageDateNumber(dayNumber: weekDay.dayNumber, isToday: isToday)
                    .padding(.trailing, DayPageDateNumberLayout.trailingPadding)
            }

            if isToday {
                TodayChip()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(weekDay.weekdayLong), \(weekDay.dayNumber) \(weekDay.monthShort)")
        .accessibilityAddTraits(.isHeader)
    }

    /// The italic caption under the weekday. Phase 29 (9) dropped the
    /// "· Week NN" suffix that used to trail the date — TestFlight feedback
    /// found it redundant with the top-bar week label. Static so it's
    /// unit-testable without view introspection.
    static func caption(for weekDay: WeekDay) -> String {
        "\(weekDay.dayNumber) \(weekDay.monthShort)"
    }
}

enum DayPageDateNumberLayout {
    static let width: CGFloat = 128
    static let trailingPadding: CGFloat = 36

    fileprivate static let trailingGlyphGuard = "\u{00A0}"
    fileprivate static let tracking: CGFloat = -2
    fileprivate static let opacity: Double = 0.85
}

struct DayPageDateNumber: View {
    let dayNumber: Int
    let isToday: Bool

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
    @Environment(\.layoutDirection) private var layoutDirection

    static func displayText(for dayNumber: Int) -> String {
        "\(dayNumber)\(DayPageDateNumberLayout.trailingGlyphGuard)"
    }

    var body: some View {
        Text(Self.displayText(for: dayNumber))
            .font(font.font(at: Typography.pageDateNumber.size * size.scale,
                            weight: Typography.pageDateNumber.weight))
            .foregroundStyle(isToday ? theme.redInk : theme.ink)
            .opacity(DayPageDateNumberLayout.opacity)
            .tracking(DayPageDateNumberLayout.tracking)
            .rotationEffect(.degrees(RTLMath.headerRotationDegrees(for: layoutDirection)),
                            anchor: .trailing)
            .fixedSize()
            .frame(width: DayPageDateNumberLayout.width, alignment: .trailing)
            .accessibilityLabel("\(dayNumber)")
    }
}

// MARK: - Previews

#Preview("Today (cream)") {
    DayPageHeaderPreviewHost(themeKey: .cream, dayOffset: 0, isToday: true)
}

#Preview("Tomorrow (midnight)") {
    DayPageHeaderPreviewHost(themeKey: .midnight, dayOffset: 1, isToday: false)
}

/// Hosts the header over the leather + paper stack used by every other
/// Day-page primitive preview. `dayOffset` is added to the Saturday-May-16
/// anchor so the same scaffold can render today and tomorrow.
private struct DayPageHeaderPreviewHost: View {
    let themeKey: PaperThemeKey
    let dayOffset: Int
    let isToday: Bool

    var body: some View {
        let anchor = DayPageHeaderPreviewSupport.anchorDate
        let now = Calendar(identifier: .gregorian).date(byAdding: .day, value: dayOffset, to: anchor) ?? anchor
        let week = WeekMath.weekDays(forOffset: 0, today: now)
        let meta = WeekMath.weekMeta(forOffset: 0, today: now)
        let targetIdx = isToday ? 5 : 6
        let day = week.first { $0.idx == targetIdx } ?? week[0]

        return ZStack {
            BookCover()
            BookPage {
                PaperSurface {
                    DayPageHeader(weekDay: day, weekMeta: meta, isToday: isToday)
                        .padding(.top, 18)
                        .padding(.leading, 44)
                        .padding(.trailing, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 60)
        }
        .paperTheme(themeKey.theme)
    }
}

/// Static support values for the previews so we don't recompute the anchor
/// inside `body` and pollute the view DSL.
private enum DayPageHeaderPreviewSupport {
    /// Saturday May 16, 2026 at noon — the standard anchor used throughout
    /// the planner test + preview suite.
    static let anchorDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }()
}
