import SwiftUI

/// The bottom-trailing footer text — `"— May 16 —"` style — that marks each
/// day page with its date. Rendered in `Cochin-Italic 10pt` (matching the
/// mock's `font-family: "Cochin", serif; font-style: italic`) and tinted with
/// the most muted ink (`theme.ink3`) so it sits quietly at the bottom of the
/// page.
///
/// The view bakes in `.padding(.trailing, 14).padding(.bottom, 6)` so callers
/// can drop it into a `.bottomTrailing` alignment slot of a `ZStack` /
/// `PaperSurface` and have it land at the correct inset without further
/// adjustment.
///
/// `.allowsHitTesting(false)` — the page number is informational, not
/// interactive.
struct PageNumber: View {
    @Environment(\.paperTheme) private var theme

    /// Date whose month abbreviation and day-of-month populate the footer.
    let date: Date

    /// Cached formatter producing `"MMM d"` (e.g. `"May 16"`). A `static let`
    /// avoids paying the formatter's allocation on every render.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// Formatted body text, wrapped in em-dashes with a single space gutter.
    private var text: String {
        "— \(Self.formatter.string(from: date)) —"
    }

    var body: some View {
        Text(text)
            .font(.custom("Cochin-Italic", size: 10))
            .foregroundStyle(theme.ink3)
            .padding(.trailing, 14)
            .padding(.bottom, 6)
            .allowsHitTesting(false)
    }
}

#Preview("PageNumber · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                PageNumber(date: Date(timeIntervalSince1970: 1_747_392_000))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("PageNumber · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                PageNumber(date: Date(timeIntervalSince1970: 1_747_392_000))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("PageNumber · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                PageNumber(date: Date(timeIntervalSince1970: 1_747_392_000))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
