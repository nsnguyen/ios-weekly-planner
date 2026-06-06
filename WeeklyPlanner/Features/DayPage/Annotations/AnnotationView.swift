import SwiftUI

/// One free-text annotation: handwriting text in display mode (tap to
/// edit, drag to move), a focused multiline field + `TextStyleBar` in
/// edit mode. Commit-on-blur; empty text deletes (via the VM).
struct AnnotationView: View {
    let annotation: Annotation
    let layerSize: CGSize
    @Binding var editingID: UUID?
    let viewModel: DayPageViewModel

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
    @Environment(PageFlipController.self) private var flipController: PageFlipController?

    @State private var draft = ""
    @GestureState private var dragOffset: CGSize = .zero
    /// Gesture-state-backed "an annotation drag is in progress" truth.
    /// SwiftUI guarantees this resets on end/cancel/teardown; the
    /// `.onChange` below mirrors it onto the shared controller so the
    /// page-flip suppression can never strand `true` (Phase 28 contract).
    @GestureState private var isDragging: Bool = false
    @FocusState private var focused: Bool

    private var isEditing: Bool { editingID == annotation.id }

    var body: some View {
        Group {
            if isEditing { editor } else { display }
        }
        .onChange(of: isDragging) { _, dragging in
            flipController?.annotationDragActive = dragging
        }
        .onChange(of: editingID) { oldID, newID in
            // Editorship left this annotation (Done, tap-away, or another
            // annotation starting to edit): the single commit point. An
            // empty draft routes to delete in the VM, so an abandoned new
            // annotation can never strand an invisible row.
            guard oldID == annotation.id, newID != annotation.id else { return }
            let text = draft
            Task { await viewModel.commitAnnotationText(id: annotation.id, text: text) }
        }
        .onDisappear {
            // Final safety net: leaving the page mid-drag must never leave
            // navigation locked.
            flipController?.annotationDragActive = false
            // Page teardown mid-edit: editingID never transitioned, so the
            // commit above can't fire — commit here instead.
            if isEditing {
                let text = draft
                editingID = nil
                Task { await viewModel.commitAnnotationText(id: annotation.id, text: text) }
            }
        }
    }

    private var display: some View {
        Text(annotation.text)
            .font(font.font(at: 16 * size.scale, weight: annotation.isBold ? .bold : .regular))
            .foregroundStyle(annotation.colorToken.resolve(in: theme))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 220, alignment: .leading)
            .offset(dragOffset) // drag-only: the editor never moves
            .contentShape(Rectangle())
            .onTapGesture {
                draft = annotation.text
                editingID = annotation.id
            }
            .highPriorityGesture(moveGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Annotation: \(annotation.text)")
            .accessibilityHint("Double tap to edit.")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(AccessibilityIDs.annotationView(annotation.id))
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onEnded { value in
                guard layerSize.width > 0, layerSize.height > 0 else { return }
                let newUnit = Annotation.clampUnit(CGPoint(
                    x: annotation.unitX + value.translation.width / layerSize.width,
                    y: annotation.unitY + value.translation.height / layerSize.height))
                // Commit the position to the live model in the same render
                // transaction that resets `dragOffset`, so the view never
                // flashes back to its pre-drag spot while persistence runs.
                annotation.unitX = newUnit.x
                annotation.unitY = newUnit.y
                Task { await viewModel.moveAnnotation(id: annotation.id, toUnit: newUnit) }
            }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextStyleBar(
                selectedColor: annotation.colorToken,
                isBold: annotation.isBold,
                onColor: { token in
                    Task { await viewModel.setAnnotationStyle(id: annotation.id, colorToken: token) }
                },
                onBoldToggle: {
                    Task { await viewModel.setAnnotationStyle(id: annotation.id, isBold: !annotation.isBold) }
                },
                onDelete: {
                    editingID = nil
                    Task { await viewModel.deleteAnnotation(id: annotation.id) }
                },
                onDone: { focused = false })

            TextField("Write…", text: $draft, axis: .vertical)
                .font(font.font(at: 16 * size.scale, weight: annotation.isBold ? .bold : .regular))
                .foregroundStyle(annotation.colorToken.resolve(in: theme))
                .tint(theme.blueInk)
                .textFieldStyle(.plain)
                .frame(width: 220, alignment: .leading)
                .focused($focused)
                .accessibilityLabel("Annotation text")
                .accessibilityIdentifier(AccessibilityIDs.annotationActiveEditor)
        }
        .task { focused = true }
        .onChange(of: focused) { _, isFocused in
            // Losing focus relinquishes editorship; the body-level
            // `.onChange(of: editingID)` performs the single commit.
            if !isFocused, isEditing { editingID = nil }
        }
    }
}
