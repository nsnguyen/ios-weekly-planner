import SwiftUI

/// Small uppercase chrome pill used for the planner's secondary actions —
/// "Today" and "Close" in the top bar, "Cancel" / "Save" in event sheets,
/// quick filters and similar. Always a `Capsule()` outline with letter-spaced
/// 11pt bold text.
///
/// The control is a plain SwiftUI `Button`, so it picks up tap handling,
/// VoiceOver labeling, and Dynamic Type for free. `.buttonStyle(.plain)` is
/// applied to suppress SwiftUI's default fade/scale so the paper aesthetic
/// stays calm.
struct PaperPillButton: View {
    /// Visual variant. `.primary` is the saturated blue-on-cream pill used
    /// for the dominant action in its row (e.g., "Today" in the top bar).
    /// `.secondary` is a transparent pill with a thin ink-tone border used
    /// for "Close", "Cancel" and other recessive actions.
    enum Variant {
        case primary
        case secondary
    }

    /// Padding preset. `.compact` (5×11) is for dense rows like the top bar
    /// of bottom sheets; `.regular` (6×14) is for the planner's main chrome.
    enum Size {
        case compact
        case regular

        /// Inset applied symmetrically around the button label.
        var insets: EdgeInsets {
            switch self {
            case .compact:
                EdgeInsets(top: 5, leading: 11, bottom: 5, trailing: 11)
            case .regular:
                EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            }
        }
    }

    @Environment(\.paperTheme) private var theme

    /// Label text. Rendered uppercased via `.textCase(.uppercase)`, so the
    /// caller should pass it in its natural casing (e.g., `"Today"`, not
    /// `"TODAY"`).
    var title: String

    /// Visual variant. Defaults to `.primary`.
    var variant: Variant = .primary

    /// Padding preset. Defaults to `.regular`.
    var size: Size = .regular

    /// Tap handler. Invoked synchronously on the main actor by the underlying
    /// `Button`.
    var action: () -> Void

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            theme.cream
        case .secondary:
            theme.ink
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            theme.blueInk
        case .secondary:
            Color.clear
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(foregroundColor)
                .padding(size.insets)
                .background(backgroundColor, in: Capsule())
                .overlay {
                    if variant == .secondary {
                        Capsule()
                            .stroke(theme.ink3, lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview("PaperPillButton · Cream") {
    PaperPillButtonPreviewHost()
        .paperTheme(.cream)
}

#Preview("PaperPillButton · Kraft") {
    PaperPillButtonPreviewHost()
        .paperTheme(.kraft)
}

#Preview("PaperPillButton · Midnight") {
    PaperPillButtonPreviewHost()
        .paperTheme(.midnight)
}

/// Preview-only host that places each variant × size combination over a
/// leather `BookCover` background — the same surface the chrome pill actually
/// sits on at runtime in the planner's top bar.
private struct PaperPillButtonPreviewHost: View {
    @State private var lastTapped: String = ""

    var body: some View {
        ZStack {
            BookCover()
            VStack(spacing: 16) {
                PaperPillButton(title: "Today", variant: .primary, size: .regular) {
                    lastTapped = "primary-regular"
                }
                PaperPillButton(title: "Today", variant: .primary, size: .compact) {
                    lastTapped = "primary-compact"
                }
                PaperPillButton(title: "Close", variant: .secondary, size: .regular) {
                    lastTapped = "secondary-regular"
                }
                PaperPillButton(title: "Close", variant: .secondary, size: .compact) {
                    lastTapped = "secondary-compact"
                }
            }
            .padding(40)
        }
    }
}
