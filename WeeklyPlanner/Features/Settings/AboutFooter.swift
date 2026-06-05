import SwiftUI

/// Finished settings trailer (Phase 36a #47): centered two-line sign-off
/// with the real bundle version. Privacy/Terms links land with Phase 40
/// once those documents exist.
struct AboutFooter: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(spacing: 3) {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: theme.ink, location: 0.5),
                .init(color: .clear, location: 1.0),
            ], startPoint: .leading, endPoint: .trailing)
                .opacity(0.25)
                .frame(width: 120, height: 1)
                .padding(.bottom, 7)

            Text("The Planner · \(AppVersion.current())")
                .font(font.font(at: 16 * size.scale, weight: .regular))
                .italic()
                .foregroundStyle(theme.ink3)

            Text("made with care")
                .font(font.font(at: 13 * size.scale, weight: .regular))
                .italic()
                .foregroundStyle(theme.inkDecorative)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Planner, version \(AppVersion.current())")
    }
}

#Preview("AboutFooter · cream") {
    AboutFooter()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
