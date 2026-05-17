import SwiftUI

/// Small chrome-style "Today" pill that appears beside the Day/Week toggle
/// when the user has navigated away from the current week. Tapping it asks
/// the parent to reset `weekOffset` to zero and re-focus today's weekday.
///
/// Visually distinct from `PaperPillButton`: this is a rectangular 5pt
/// rounded pill rather than a capsule, with a faint white-on-leather fill
/// and a 0.5pt `chromeMuted` border. The font is the system stack at 11pt
/// medium — deliberately small, since the pill sits in the secondary row
/// next to the Day/Week toggle.
struct TodayPill: View {
    /// Invoked when the user taps the pill. The parent jumps back to the
    /// current week and today's weekday.
    var action: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text("Today")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.chromeText)
                .padding(.vertical, 3)
                .padding(.horizontal, 9)
                .background(Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(theme.chromeMuted, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to today")
    }
}

// MARK: - Previews

#Preview("TodayPill · cream") {
    ZStack {
        BookCover()
        TodayPill {}
            .padding(40)
    }
    .paperTheme(.cream)
}

#Preview("TodayPill · midnight") {
    ZStack {
        BookCover()
        TodayPill {}
            .padding(40)
    }
    .paperTheme(.midnight)
}
