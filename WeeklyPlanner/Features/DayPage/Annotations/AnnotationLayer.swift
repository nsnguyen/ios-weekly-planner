import SwiftUI

/// Overlay hosting all of a day's annotations, positioned in unit space.
/// Hit-testing: the ZStack has no background, so only the annotation
/// views themselves receive touches — empty paper stays interactive
/// (scroll, taps, the creation long-press) underneath.
///
/// Layout: the top-level `GeometryReader` is load-bearing — its greedy
/// sizing is what makes this overlay fill the host content node so unit
/// math matches the creation gesture's `.local` space. Don't replace it
/// without re-anchoring the overlay's frame.
struct AnnotationLayer: View {
    let viewModel: DayPageViewModel
    @Binding var editingID: UUID?
    /// Rendered height of each note, keyed by id — written here (the only
    /// place notes are measured), read by the creation gesture to stack
    /// new notes below existing ones. Heights, not frames, on purpose:
    /// height is pure layout (independent of the `.offset` render
    /// transform below), and the gesture pairs it with live `unitY` at
    /// press time, so a note dragged a moment ago never contributes a
    /// stale bottom.
    @Binding var noteHeights: [UUID: CGFloat]

    var body: some View {
        GeometryReader { geo in
            // No identifier on this container: a SwiftUI identifier set on a
            // plain ZStack cascades onto every descendant element, clobbering
            // the per-annotation and style-bar identifiers UI tests rely on.
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.annotations, id: \.id) { annotation in
                    AnnotationView(annotation: annotation,
                                   layerSize: geo.size,
                                   editingID: $editingID,
                                   viewModel: viewModel)
                        // Measured inside the offset so the value is the
                        // note's laid-out size, untouched by translation.
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { height in
                            noteHeights[annotation.id] = height
                        }
                        .onDisappear {
                            noteHeights.removeValue(forKey: annotation.id)
                        }
                        // Top-leading anchor: unitX/unitY address the note's
                        // top-left corner (not its center), so its leading edge
                        // lands exactly where the unit position maps. The host
                        // ZStack is `.topLeading`, so each note starts at the
                        // layer origin and this offset shifts its corner. Drag
                        // is unaffected — `moveGesture` is translation-based.
                        .offset(x: geo.size.width * annotation.unitX,
                                y: geo.size.height * annotation.unitY)
                }
            }
        }
    }
}
