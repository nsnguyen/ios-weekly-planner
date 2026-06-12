import CoreGraphics
import Foundation

/// Day-page geometry shared between the page chrome and the annotation
/// creation gesture, so the annotation column can never drift from the
/// page's leading margin.
enum DayPageLayout {
    /// Leading page margin — the red rule line where events, to-dos, and the
    /// annotation column all begin.
    static let pageMargin: CGFloat = 44

    /// Vertical gap between the stacking anchor (lowest existing content)
    /// and a new note's top edge. A visual breathing gap, intentionally
    /// smaller than the paper's 28 pt ruled-line rhythm — placement is
    /// measured, not line-snapped.
    static let stackSpacing: CGFloat = 12

    /// A new note's top edge never lands closer than this to the page
    /// bottom, so a note stacked onto a full page stays visibly on the
    /// paper (overlap down there is accepted as "the page is full").
    /// For layers shorter than this (unreachable in production — the
    /// layer is floored to the viewport height), the clamp target goes
    /// negative and `clampUnit` floors the note to the page top.
    static let bottomHeadroom: CGFloat = 60

    /// Unit-space (0…1) position for a new long-press annotation: leading
    /// edge on the event column, top edge one `stackSpacing` below the
    /// lowest existing content — the content column (header → events →
    /// inbox) or the lowest annotation bottom, whichever is lower. The
    /// press location plays no part: notes stack top-down like writing on
    /// a notepad. `Annotation.clampUnit` is the NaN/inf safety net for a
    /// degenerate (zero) layer size.
    static func stackedAnnotationUnit(contentBottom: CGFloat,
                                      annotationBottoms: [CGFloat],
                                      layerSize: CGSize) -> CGPoint {
        let anchor = max(contentBottom, annotationBottoms.max() ?? 0)
        let y = min(anchor + stackSpacing, layerSize.height - bottomHeadroom)
        return Annotation.clampUnit(CGPoint(x: pageMargin / layerSize.width,
                                            y: y / layerSize.height))
    }

    /// One computed auto-nudge: move note `id` so its top sits at `unitY`.
    struct AnnotationNudge: Equatable {
        let id: UUID
        let unitY: Double
    }

    /// Restack plan for content growth: machine-placed (`autoPlaced`) notes
    /// whose tops the content column has grown past are restacked below it —
    /// in their current vertical order, each clearing the content, every
    /// pinned/editing/non-colliding note, and every note already restacked
    /// (page-full headroom pile-ups excepted, as at creation). Down-nudge only:
    /// a note whose target isn't strictly below its current top is left in place,
    /// so a settled page emits no nudges.
    /// Pinned (user-dragged), editing, and below-content notes never move.
    /// Pure: plain values in, nudges out — unit-testable without SwiftUI.
    static func nudgesForContentGrowth(notes: [(id: UUID, unitY: Double, autoPlaced: Bool)],
                                       editingID: UUID?,
                                       contentBottom: CGFloat,
                                       noteHeights: [UUID: CGFloat],
                                       layerSize: CGSize) -> [AnnotationNudge] {
        guard layerSize.width > 0, layerSize.height > 0 else { return [] }
        let colliding = notes
            .filter { $0.autoPlaced && $0.id != editingID
                && CGFloat($0.unitY) * layerSize.height < contentBottom }
            .sorted { $0.unitY < $1.unitY }
        guard !colliding.isEmpty else { return [] }

        let collidingIDs = Set(colliding.map(\.id))
        var bottoms = notes
            .filter { !collidingIDs.contains($0.id) }
            .map { CGFloat($0.unitY) * layerSize.height + (noteHeights[$0.id] ?? 0) }

        var nudges: [AnnotationNudge] = []
        for note in colliding {
            let unit = stackedAnnotationUnit(contentBottom: contentBottom,
                                             annotationBottoms: bottoms,
                                             layerSize: layerSize)
            let currentTop = CGFloat(note.unitY) * layerSize.height
            let newTop = CGFloat(unit.y) * layerSize.height
            if newTop > currentTop {
                nudges.append(AnnotationNudge(id: note.id, unitY: unit.y))
                bottoms.append(newTop + (noteHeights[note.id] ?? 0))
            } else {
                // Down-nudge only: at the page-full headroom clamp (or after
                // a layer resize) the target isn't below the note — leave it
                // where it is, emit nothing, and stack later notes against
                // its actual position. Keeps repeated growth events no-op
                // once the page has settled.
                bottoms.append(currentTop + (noteHeights[note.id] ?? 0))
            }
        }
        return nudges
    }
}
