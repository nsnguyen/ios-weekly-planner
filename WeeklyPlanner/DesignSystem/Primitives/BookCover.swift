import SwiftUI

/// Full-bleed leather book-cover background. Renders the 160° linear gradient
/// defined on `PaperTheme.bookCover` and extends past the safe area.
///
/// Layering role: bottom-most layer of the planner screen. The `BookPage`
/// composite sits on top of this, with a small margin so the dark leather
/// shows around the inner page. No texture overlay — the leather effect is
/// the gradient alone.
struct BookCover: View {
    @Environment(\.paperTheme) private var theme

    var body: some View {
        theme.bookCover
            .ignoresSafeArea()
    }
}

#Preview("BookCover · Cream") {
    BookCover()
        .paperTheme(.cream)
}

#Preview("BookCover · Kraft") {
    BookCover()
        .paperTheme(.kraft)
}

#Preview("BookCover · Midnight") {
    BookCover()
        .paperTheme(.midnight)
}
