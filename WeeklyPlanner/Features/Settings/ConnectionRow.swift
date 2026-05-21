import SwiftUI

/// One row of the Connections card: 28pt logo · label + detail (flex) ·
/// 44×26 PaperToggle. The label is system 14pt 600 ink; the detail is system
/// 11pt ink2. The toggle's `isOn` binding is supplied by the parent; the
/// `isEnabled` flag dims and disables the toggle (used by the Apple Mail and
/// Google Calendar rows).
struct ConnectionRow<Logo: View>: View {
    let logo: Logo
    let label: String
    let detail: String
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    var onTap: (() -> Void)? = nil

    @Environment(\.paperTheme) private var theme

    init(
        @ViewBuilder logo: () -> Logo,
        label: String,
        detail: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.logo = logo()
        self.label = label
        self.detail = detail
        _isOn = isOn
        self.isEnabled = isEnabled
        self.onTap = onTap
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack { logo }
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.ink2)
                    .lineSpacing(1.3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PaperToggle(isOn: $isOn, style: .regular)
                .opacity(isEnabled ? 1 : 0.4)
                .allowsHitTesting(isEnabled)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

#Preview("ConnectionRow — Gmail off") {
    StatefulPreview(initial: false) { binding in
        ConnectionRow(
            logo: { GmailBrandLogo() },
            label: "Gmail",
            detail: "Tap to connect — pulls events & reminders from your inbox",
            isOn: binding
        )
        .padding()
        .background(PaperTheme.cream.creamHi)
        .paperTheme(.cream)
    }
}

/// Local preview helper — gives the binding a backing store so #Preview can
/// render without an enclosing view-model.
private struct StatefulPreview<Content: View>: View {
    @State private var value: Bool
    let content: (Binding<Bool>) -> Content

    init(initial: Bool, @ViewBuilder content: @escaping (Binding<Bool>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
