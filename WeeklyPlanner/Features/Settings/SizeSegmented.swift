import SwiftUI

/// S / M / L / XL / XXL control. Each segment renders its label in the
/// current handwriting font at a preview size, so the user sees the
/// choice before committing. The active segment lifts via a `creamHi`
/// background + a 0.5pt rule outline + a 1pt soft shadow.
///
/// Preview sizes grow with the segment index and ignore `\.paperSize`
/// so the comparison stays honest.
struct SizeSegmented: View {
    @Binding var selection: PaperSize
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    private static func displaySize(for size: PaperSize) -> CGFloat {
        let index = CGFloat(PaperSize.allCases.firstIndex(of: size) ?? 0)
        return 13 + 3 * index
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PaperSize.allCases, id: \.self) { size in
                Button {
                    selection = size
                } label: {
                    Text(size.displayName)
                        .font(font.font(at: Self.displaySize(for: size), weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(segmentBackground(active: size == selection))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIDs.settingsSizeSegment(size.rawValue))
                .accessibilityAddTraits(size == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.rule, lineWidth: 0.5)))
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func segmentBackground(active: Bool) -> some View {
        if active {
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.creamHi)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.rule, lineWidth: 0.5))
        } else {
            Color.clear
        }
    }
}

#Preview("SizeSegmented · cream") {
    StatefulPreviewWrapper(PaperSize.m) { binding in
        SizeSegmented(selection: binding)
            .padding()
            .background(PaperTheme.cream.cream)
    }
    .paperTheme(.cream)
}

/// Tiny preview helper — wraps a `@State` so we can drive a binding inside
/// `#Preview` without writing a host view per call site.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
