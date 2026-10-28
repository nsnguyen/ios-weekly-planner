import SwiftUI

/// The single paper stack every page uses (Phase 44). Replaces the
/// copy-pasted `ZStack { PaperGrain(); RuledLines(); RedMarginLine();
/// HolePunches() }` sites and branches on the selected template.
struct PaperBackground: View {
    var showsHolePunches = true

    @Environment(\.paperTemplate) private var template

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperGrain()
            switch template {
            case .ruled:
                RuledLines()
            case .blank:
                EmptyView()
            case .dotGrid:
                DotGrid()
            case .grid:
                GridLines()
            }
            if template.showsRedMargin {
                RedMarginLine()
            }
            if showsHolePunches {
                HolePunches()
            }
        }
        .accessibilityHidden(true)
    }
}
