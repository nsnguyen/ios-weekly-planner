import SwiftUI

/// One cell of the `PaperTabBar`. Pure VStack — icon over label — with the
/// active state distinguished only by color brightness (`chromeText`
/// for active, `chromeMuted` for inactive). Matches the paper-mode
/// `TabBar` in `docs/mock/overlays.jsx`: no cream bookmark behind the
/// active cell, no font-weight swap, just two shades of the same chrome
/// ink against the leather background.
struct PaperTab: View {
    let tab: Tab
    let isActive: Bool
    let action: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dtSize

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                switch DynamicTypeLayout.tabBarLabelStyle(at: dtSize) {
                case .full:
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(color)
                case .truncate:
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                case .iconOnly:
                    EmptyView()
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var color: Color {
        isActive ? theme.chromeText : theme.chromeMuted
    }

    private var iconName: String {
        switch tab {
        case .calendar: return "calendar"
        case .review: return "tray"
        case .settings: return "gearshape"
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
    .padding(.top, 6)
    .background(PaperTheme.cream.bookCover)
    .paperTheme(.cream)
}
