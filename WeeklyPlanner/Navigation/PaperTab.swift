import SwiftUI

/// One cell of the `PaperTabBar`. Layers a cream "index-tab" bookmark behind
/// the icon+label when active, so the active tab reads as a paper bookmark
/// poking out of the leather book.
///
/// Geometry, per spec:
/// - Cell padding `top: 8`, column spacing `3`.
/// - Icon `22pt`, label `10pt` system, weight `.bold` active / `.medium` inactive.
/// - Active ink/icon `theme.ink`; inactive `theme.chromeMuted`.
/// - Bookmark `52×26pt` cream rectangle, rounded `4pt` at the top corners,
///   centered horizontally, vertical offset `-8pt` so it extends above the
///   tab area. Lives at the bottom of the `ZStack` so the icon/label paint
///   on top.
struct PaperTab: View {
    let tab: Tab
    let isActive: Bool
    let action: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                bookmark
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isActive)

                VStack(spacing: 3) {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? theme.ink : theme.chromeMuted)
                    Text(label)
                        .font(.system(size: 10, weight: isActive ? .bold : .medium))
                        .tracking(0.1)
                        .foregroundStyle(isActive ? theme.ink : theme.chromeMuted)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var bookmark: some View {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4,
                                                   bottomLeading: 0,
                                                   bottomTrailing: 0,
                                                   topTrailing: 4),
                               style: .continuous)
            .fill(theme.cream)
            .frame(width: 52, height: 26)
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: -1)
            .offset(y: -8)
    }

    private var iconName: String {
        switch tab {
        case .calendar: return "calendar"
        case .review: return "tray.fill"
        case .settings: return "gearshape.fill"
        }
    }

    private var label: String {
        switch tab {
        case .calendar: return "Calendar"
        case .review: return "Review"
        case .settings: return "Settings"
        }
    }
}

#Preview("PaperTab · active + inactive") {
    HStack(spacing: 0) {
        PaperTab(tab: .calendar, isActive: true, action: {})
        PaperTab(tab: .review, isActive: false, action: {})
        PaperTab(tab: .settings, isActive: false, action: {})
    }
    .padding(.vertical, 8)
    .background(PaperTheme.cream.bookCover)
    .paperTheme(.cream)
}
