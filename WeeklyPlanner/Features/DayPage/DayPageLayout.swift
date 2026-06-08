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
}
