import SwiftUI

/// Editable card content used by `PaperEventSheet` when `mode` is
/// `.edit` or `.create`. Renders a Save / Cancel header bar above
/// `InkTextField` (title) + `PaperDateTimeRow` (start, end) +
/// `CategorySwatchRow` + `LocationField` + the existing alert rows,
/// plus an optional Delete button at the bottom (only in edit mode).
struct EditableEventContent: View {
    @Bindable var composer: EventComposerState
    let canSave: Bool
    let isCreate: Bool
    let showsDelete: Bool
    let onSave: () async -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(EdgeInsets(top: 38, leading: 44, bottom: 14, trailing: 18))

            VStack(alignment: .leading, spacing: 0) {
                InkTextField(isCreate ? "New event" : "Title",
                             text: $composer.title,
                             variant: .title)
                    .padding(.bottom, 12)

                PaperDateTimeRow(label: "Starts", date: $composer.start)
                PaperDateTimeRow(label: "Ends",
                                 date: $composer.end,
                                 invalidHint: !composer.timesAreValid)
                CategorySwatchRow(selection: $composer.category)
                LocationField(text: $composer.location)
                NotesField(text: $composer.notes)

                if showsDelete {
                    Button(action: onDelete) {
                        Text("Delete event")
                            .font(font.font(at: 15 * size.scale, weight: .regular))
                            .foregroundStyle(theme.redInk)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .onChange(of: composer.start) { _, newStart in
            if newStart >= composer.end {
                composer.end = newStart.addingTimeInterval(3600)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button("Cancel", action: onCancel)
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)
                .buttonStyle(.plain)

            Spacer()

            Text(isCreate ? "New event" : "Edit event")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)

            Spacer()

            Button {
                Task { await onSave() }
            } label: {
                Text("Save")
                    .font(font.font(at: 15 * size.scale, weight: .bold))
                    .foregroundStyle(canSave ? theme.blueInk : theme.ink3)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .accessibilityIdentifier("paperEventSheet.save")
        }
    }
}
