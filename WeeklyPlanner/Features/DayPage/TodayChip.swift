import SwiftUI

/// Dashed-border red pill that labels today's page and shows the current time
/// in `h:mm a` form (e.g., `"TODAY · 2:12 PM"`). The label is wrapped in a
/// `TimelineView(.everyMinute)` so the displayed time refreshes once a minute
/// while the page is on-screen — no manual `Timer` plumbing required.
///
/// Visuals: a 5pt red dot followed by uppercase 10pt bold tracked text. The
/// pill is filled with `theme.redInk` at 10% opacity and outlined with a fine
/// dashed stroke via the shared `.dashedBorder` modifier from Phase 05.
///
/// All colors come from `@Environment(\.paperTheme)`; the only hardcoded
/// numeric values are the chip's geometry (dot radius, paddings, corner
/// radius), which intentionally live here because the chip is the only place
/// in the design system that uses these specific values.
struct TodayChip: View {
    @Environment(\.paperTheme) private var theme

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 5) {
                Circle()
                    .fill(theme.redInk)
                    .frame(width: 5, height: 5)

                Text("TODAY · \(Self.formatter.string(from: context.date))")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(theme.redInk)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 9)
            .background(RoundedRectangle(cornerRadius: 3)
                .fill(theme.redInk.opacity(0.1)))
            .dashedBorder(color: theme.redInk,
                          dash: [3, 2],
                          lineWidth: 0.5,
                          cornerRadius: 3)
        }
    }

    /// Cached `DateFormatter` that yields `"2:12 PM"` style strings. The
    /// `en_US_POSIX` locale guarantees uppercase `AM`/`PM` regardless of the
    /// device's region settings.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Previews

#Preview("TodayChip · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                TodayChip()
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
