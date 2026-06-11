import CoreGraphics

/// Day-page geometry shared between the page chrome and the annotation
/// creation gesture, so the annotation column can never drift from the
/// page's leading margin.
enum DayPageLayout {
    /// Leading page margin — the red rule line where events, to-dos, and the
    /// annotation column all begin.
    static let pageMargin: CGFloat = 44

    /// Unit-space (0…1) position for a new long-press annotation: leading
    /// edge snapped to the event column (`pageMargin`), vertical position at
    /// the press point. Horizontal press position is intentionally ignored so
    /// every new note lines up in the same column. `Annotation.clampUnit` is
    /// the NaN/inf safety net for a degenerate (zero) layer size.
    static func annotationCreationUnit(pressY: CGFloat, layerSize: CGSize) -> CGPoint {
        Annotation.clampUnit(CGPoint(x: pageMargin / layerSize.width,
                                     y: pressY / layerSize.height))
    }

    /// Vertical gap between the stacking anchor (lowest existing content)
    /// and a new note's top edge. A visual breathing gap, intentionally
    /// smaller than the paper's 28 pt ruled-line rhythm — placement is
    /// measured, not line-snapped.
    static let stackSpacing: CGFloat = 12

    /// A new note's top edge never lands closer than this to the page
    /// bottom, so a note stacked onto a full page stays visibly on the
    /// paper (overlap down there is accepted as "the page is full").
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
}
