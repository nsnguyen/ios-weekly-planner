import SwiftUI

/// The composite container that hosts every piece of book chrome around a
/// generic content slot. Group A delivers the chrome (spine, edge stripes,
/// binding shadow, page curl); Group B adds the cream paper surface, ruled
/// lines, hole punches, and friends inside the content slot.
///
/// Layering (back to front):
/// 1. `BookSpine` — dark, rounded background container.
/// 2. `EdgeStripes` — stacked-paper pattern on the trailing edge, inset 6pt
///    from the top and bottom of the spine.
/// 3. `content` — the caller's view, clipped to a slightly less-rounded
///    `UnevenRoundedRectangle` so it nests cleanly inside the spine. The
///    caller is expected to drop a `PaperSurface` here that fills edge-to-edge;
///    hole-punch / red-margin / ruled-line positions are measured from the
///    surface's leading edge. `BookPage` itself does NOT apply
///    `Spacing.pageInset`; that semantic belongs to the event-row content
///    positioned INSIDE the `PaperSurface`.
/// 4. `BindingShadow` — gradient on the leading edge that falls onto content.
/// 5. `PageCurl` — folded-corner decoration in the bottom-trailing corner.
///
/// The page itself does not ignore the safe area; the caller positions and
/// sizes the `BookPage` and decides whether (and where) to bleed outward.
struct BookPage<Content: View>: View {
    @Environment(\.paperTheme) private var theme

    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            BookSpine()

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(UnevenRoundedRectangle(cornerRadii: Spacing.bookPageCornerRadius))

            EdgeStripes()
                .frame(width: Spacing.pageEdgeStripeWidth)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .allowsHitTesting(false)

            BindingShadow()

            PageCurl()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

#Preview("BookPage · Cream") {
    ZStack {
        BookCover()
        BookPage {
            Color.clear
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("BookPage · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            Color.clear
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("BookPage · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            Color.clear
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}

#Preview("BookPage · with placeholder content") {
    ZStack {
        BookCover()
        BookPage {
            ZStack {
                Color(hex: "#FAF6E9")
                VStack(spacing: 8) {
                    Text("Saturday")
                        .font(.title)
                    Text("16 May · Week 20")
                        .italic()
                }
                .foregroundStyle(Color(hex: "#1A1A2A"))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
