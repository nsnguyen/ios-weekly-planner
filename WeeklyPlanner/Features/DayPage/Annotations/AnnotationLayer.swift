import SwiftUI

/// Overlay hosting all of a day's annotations, positioned in unit space.
/// Hit-testing: the ZStack has no background, so only the annotation
/// views themselves receive touches — empty paper stays interactive
/// (scroll, taps, the creation long-press) underneath.
struct AnnotationLayer: View {
    let viewModel: DayPageViewModel
    @Binding var editingID: UUID?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.annotations, id: \.id) { annotation in
                    AnnotationView(annotation: annotation,
                                   layerSize: geo.size,
                                   editingID: $editingID,
                                   viewModel: viewModel)
                        .position(x: geo.size.width * annotation.unitX,
                                  y: geo.size.height * annotation.unitY)
                }
            }
            .accessibilityIdentifier(AccessibilityIDs.annotationsLayer)
        }
    }
}
