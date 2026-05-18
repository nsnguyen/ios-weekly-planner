import SwiftUI

/// The pre-baked-queries list shown in State A of the AI search overlay
/// (no query typed, no answer yet). Renders the
/// `AISearchCannedData.suggestions` array as a tappable column of
/// handwritten lines, each prefixed with `"↳ "` to read as a recommended
/// reply rather than a generic menu item.
///
/// Layout matches the spec verbatim:
/// - Heading `"Try asking"` — handwriting 18pt bold, with a `WavyUnderline`
///   in 25%-opacity ink as the only ornament.
/// - Items — handwriting 18pt regular blue-ink, 5pt vertical inset, full-row
///   hit target via `.frame(maxWidth: .infinity)` + `.contentShape`.
/// - Footer microcopy — italic 10pt `Cochin-Italic`, advertising
///   on-device-ness so the user understands why this is safe to use.
///
/// `onTap` is dispatched synchronously on the main actor; callers typically
/// fire-and-forget a `Task { await viewModel.ask(suggestion) }`.
struct SuggestionList: View {
    /// Invoked when the user taps a suggestion. The whole `AISuggestion` is
    /// forwarded (not just the text) so future phases can route on `id`.
    var onTap: (AISuggestion) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Try asking")
                .font(font.font(at: 18, weight: .bold))
                .foregroundStyle(theme.ink)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .wavyUnderline(color: theme.ink.opacity(0.25))

            ForEach(AISearchCannedData.suggestions) { suggestion in
                Button {
                    onTap(suggestion)
                } label: {
                    HStack(spacing: 0) {
                        Text("↳ \(suggestion.text)")
                            .font(font.font(at: 18, weight: .regular))
                            .foregroundStyle(theme.blueInk)
                    }
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text("On-device · your week stays private.")
                .font(.custom("Cochin-Italic", size: 10))
                .foregroundStyle(theme.ink3)
                .padding(.top, 18)
        }
    }
}
