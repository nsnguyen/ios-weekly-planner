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
                        // The note's laid-out size; the .offset below is a
                        // render translation and never affects it. The id is
                        // captured by value so teardown never reads an
                        // attribute of a deleted SwiftData model.
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { [id = annotation.id] height in
                            noteHeights[id] = height
                        }
                        .onDisappear { [id = annotation.id] in
                            noteHeights.removeValue(forKey: id)
                        }
                        // Vertical-only, left-locked: the leading edge is pinned
                        // to the page margin so every note forms one left-aligned
                        // column. Stored `unitX` no longer drives X — a note
                        // dragged off-column under the old free-2D behavior snaps
                        // back here, and the value self-heals to the margin on its
                        // next drag (see verticalDragUnit). `unitY` still addresses
                        // the note's top edge against the `.topLeading` host ZStack.
                        .offset(x: DayPageLayout.pageMargin,
                                y: geo.size.height * annotation.unitY)
                }
            }
        }
    }
}
