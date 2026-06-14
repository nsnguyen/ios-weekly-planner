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

    /// Unit-space destination for a vertical-only note drag: the leading
    /// edge stays locked to the page margin (notes form a single
    /// left-aligned column), and only the top's Y moves by the drag
    /// translation. The starting X is intentionally not a parameter — it is
    /// always the margin. `Annotation.clampUnit` keeps the note on the page
    /// and is the NaN/inf safety net for a degenerate (zero) layer size,
    /// mirroring `stackedAnnotationUnit`.
    static func verticalDragUnit(currentUnitY: Double,
                                 translationHeight: CGFloat,
                                 layerSize: CGSize) -> CGPoint {
        Annotation.clampUnit(CGPoint(x: pageMargin / layerSize.width,
                                     y: CGFloat(currentUnitY) + translationHeight / layerSize.height))
    }

    /// One note's computed slot in the compacted stack.
    struct AnnotationPlacement: Equatable {
        let id: UUID
        let unitY: Double
    }

    /// Pack every note into a gapless column directly below the content, in
    /// current vertical (`unitY`) order — the order key, so a note dropped
    /// between two others sorts into that slot. Bidirectional (closes gaps
    /// above and below) and idempotent (a settled stack returns identical
    /// positions, so the caller writes nothing). Page-full notes pile at the
    /// `bottomHeadroom` clamp, exactly as creation/auto-stacking do.
    /// `Annotation.clampUnit` keeps each slot on the page (NaN/inf net for a
    /// degenerate layer). Pure: plain values in, placements out.
    static func compactedStack(notes: [(id: UUID, unitY: Double, height: CGFloat)],
                               contentBottom: CGFloat,
                               layerSize: CGSize) -> [AnnotationPlacement] {
        guard layerSize.width > 0, layerSize.height > 0 else { return [] }
        let ordered = notes.sorted { $0.unitY < $1.unitY }
        var placements: [AnnotationPlacement] = []
        var cursor = contentBottom
        for note in ordered {
            let top = min(cursor + stackSpacing, layerSize.height - bottomHeadroom)
            let unitY = Annotation.clampUnit(CGPoint(x: 0, y: top / layerSize.height)).y
            placements.append(AnnotationPlacement(id: note.id, unitY: unitY))
            cursor = top + note.height
        }
        return placements
    }
}
