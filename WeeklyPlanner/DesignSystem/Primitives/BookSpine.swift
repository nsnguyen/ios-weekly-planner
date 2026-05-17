import SwiftUI

/// The dark book-spine container that the cream page surface clips into.
///
/// Renders a solid `theme.bookSpine` fill clipped by an `UnevenRoundedRectangle`
/// (`topLeading: 4, topTrailing: 14, bottomLeading: 4, bottomTrailing: 14`) — the
/// bound edge on the left is only slightly rounded, the trailing free edge is
/// rounded more. On top of the fill, two inset shadows are drawn as overlay
/// linear gradients to suggest the page sinking into the binding:
///
/// - Leading edge: heavier `inset 8pt 0 14pt rgba(0,0,0,0.45)`.
/// - Trailing edge: lighter `inset -4pt 0 8pt rgba(0,0,0,0.2)`.
///
/// Layering role: parent container for `EdgeStripes`, page content,
/// `BindingShadow`, and `PageCurl` inside a `BookPage`.
struct BookSpine: View {
    @Environment(\.paperTheme) private var theme

    /// Width over which the leading inset shadow fades from full opacity to 0.
    /// Matches the CSS `inset 8pt 0 14pt` blur radius — the shadow plus its
    /// soft falloff together cover ~22pt from the edge.
    private static let leadingShadowWidth: CGFloat = 22

    /// Width over which the trailing inset shadow fades.
    /// Matches CSS `inset -4pt 0 8pt` — narrower, lighter falloff.
    private static let trailingShadowWidth: CGFloat = 12

    var body: some View {
        ZStack {
            theme.bookSpine
            leadingShadow
            trailingShadow
        }
        .compositingGroup()
        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4,
                                                             bottomLeading: 4,
                                                             bottomTrailing: 14,
                                                             topTrailing: 14)))
    }

    /// Heavy darkening on the leading edge — the bound side of the spine.
    private var leadingShadow: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [Color.black.opacity(0.45), .clear],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(width: Self.leadingShadowWidth)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    /// Lighter darkening on the trailing edge — where the page meets the
    /// outer book hull.
    private var trailingShadow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, Color.black.opacity(0.20)],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(width: Self.trailingShadowWidth)
        }
        .allowsHitTesting(false)
    }
}

#Preview("BookSpine · Cream") {
    ZStack {
        BookCover()
        BookSpine()
            .frame(width: 340, height: 580)
    }
    .paperTheme(.cream)
}

#Preview("BookSpine · Kraft") {
    ZStack {
        BookCover()
        BookSpine()
            .frame(width: 340, height: 580)
    }
    .paperTheme(.kraft)
}

#Preview("BookSpine · Midnight") {
    ZStack {
        BookCover()
        BookSpine()
            .frame(width: 340, height: 580)
    }
    .paperTheme(.midnight)
}
