import SwiftUI

/// Placeholder copy rendered on a Day page when the focused day has neither
/// confirmed events nor pending inbox suggestions. The aesthetic intent is the
/// opposite of an "empty state" alert — there is no icon, no call-to-action,
/// and no muted card. Just a handwritten italic line on the paper that reads
/// like a margin note the user wrote to themselves.
///
/// In Phase 23 the empty state gained an optional `onAddTask` CTA that
/// flips the day-vm's task composer into composing mode. Phase 22's plan
/// kept the row aesthetic; we add a single underlined inline link below
/// the main caption to avoid disturbing the "free page" feel.
struct EmptyDayState: View {
    var onAddTask: (() -> Void)?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing scheduled. A free page.")
                .font(font.font(at: 20 * size.scale, weight: .regular).italic())
                .foregroundStyle(theme.ink3)

            if let onAddTask {
                Button(action: onAddTask) {
                    Text("+ add a task")
                        .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                        .foregroundStyle(theme.blueInk)
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("daypage.empty.addTask")
            }
        }
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
                EmptyDayState(onAddTask: {})
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
