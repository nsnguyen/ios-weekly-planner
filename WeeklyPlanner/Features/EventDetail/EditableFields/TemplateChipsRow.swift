import SwiftUI

/// Horizontal quick-template chips shown at the top of the CREATE event
/// sheet. Tapping one pre-fills the composer (it stays fully editable).
struct TemplateChipsRow: View {
    let onPick: (EventTemplate) -> Void

    @Environment(\.eventTemplateStore) private var templateStore
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @State private var templates: [EventTemplate] = []
    @State private var showEditor = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(templates) { template in
                    Button {
                        onPick(template)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryPalette.inkColor(template.category, in: theme))
                                .frame(width: 7, height: 7)
                            Text(template.title)
                                .font(font.font(at: 14 * size.scale, weight: .regular))
                                .foregroundStyle(theme.ink)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(theme.creamHi))
                        .overlay(Capsule().strokeBorder(theme.rule, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(template.title) template")
                    .accessibilityHint("Double tap to pre-fill the event.")
                    .accessibilityIdentifier(AccessibilityIDs.eventTemplateChip(template.id))
                }

                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(font.font(at: 14 * size.scale, weight: .regular))
                        .foregroundStyle(theme.ink2)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(theme.creamHi))
                        .overlay(Capsule().strokeBorder(theme.rule, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit quick-add templates")
                .accessibilityIdentifier(AccessibilityIDs.eventTemplatesEdit)
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 10)
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .eventTemplateStoreDidChange)) { _ in
            reload()
        }
        .sheet(isPresented: $showEditor) {
            TemplateEditorSheet()
        }
    }

    private func reload() {
        if let templateStore {
            templates = ((try? templateStore.templates()) ?? []).map(\.asTemplate)
        } else {
            templates = EventTemplate.curated
        }
    }
}

#Preview("TemplateChipsRow · cream") {
    TemplateChipsRow { _ in }
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
