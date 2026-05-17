import SwiftUI

/// Placeholder copy rendered on a Day page when the focused day has neither
/// confirmed events nor pending inbox suggestions. The aesthetic intent is the
/// opposite of an "empty state" alert — there is no icon, no call-to-action,
/// and no muted card. Just a handwritten italic line on the paper that reads
/// like a margin note the user wrote to themselves: a free page is good news,
/// not a hole to fill.
///
/// Tokens flow in from the environment so the message picks up the user's
/// chosen handwriting family (`paperFont`), the S/M/L size step (`paperSize`),
/// and the theme's muted ink (`theme.ink3`).
struct EmptyDayState: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        Text("Nothing scheduled. A free page.")
            .font(font.font(at: 20 * size.scale, weight: .regular).italic())
            .foregroundStyle(theme.ink3)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("EmptyDayState · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                EmptyDayState()
                    .padding(.top, 40)
                    .padding(.leading, 44)
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
