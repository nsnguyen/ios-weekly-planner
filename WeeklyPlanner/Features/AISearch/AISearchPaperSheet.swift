import SwiftUI

/// The paper sheet inside the AI search overlay. Mounts the same primitives
/// the Day page uses — `BookPage`, `PaperSurface`, `PaperGrain`,
/// `RuledLines`, `RedMarginLine`, `HolePunches` — so the overlay reads as a
/// fresh page slipped into the same book the user was reading a moment ago.
///
/// Inside the paper surface lives the actual content column: an
/// `AskInputField` at the top, followed by exactly one of three states —
/// thinking indicator, rendered answer, or suggestion list — driven by the
/// view-model's `thinking` / `answer` properties.
///
/// Outer margin `top: 0, leading: 18, bottom: 18, trailing: 26` is hand-set
/// to match the rest of the app's book spacing — the page leading edge sits
/// flush with the spine and the trailing edge clears the edge-stripe band.
/// The content column inside the surface uses the same red-margin + hole-
/// punch geometry as every other page: 44pt leading inset to clear the red
/// rule, 18pt trailing.
struct AISearchPaperSheet: View {
    /// The state-bearing view model. Read-only here — the sheet observes
    /// changes through `@Observable` and forwards user input via the model's
    /// methods.
    let viewModel: AISearchViewModel

    /// Forwarded to `AnswerBlock` for citation-chip taps. The overlay
    /// closes itself first, then asks the host to open the matching event
    /// 100ms later (see `PaperAISearchView.closeOverlay`).
    var onTapCitation: (UUID) -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .topLeading) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    VStack(alignment: .leading, spacing: 0) {
                        AskInputField(text: Binding(get: { viewModel.query },
                                                    set: { viewModel.query = $0 }),
                                      onSubmit: {
                                          let query = viewModel.query
                                          Task { await viewModel.ask(text: query) }
                                      },
                                      onClear: { viewModel.clear() })

                        body(for: viewModel)
                    }
                    .padding(EdgeInsets(top: 18, leading: 44, bottom: 20, trailing: 18))
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .topLeading)
                }
            }
        }
        .padding(EdgeInsets(top: 0, leading: 18, bottom: 18, trailing: 26))
    }

    /// Selects the right body view for the view-model's current state.
    /// Pulled out into a helper so the `body` accessor stays a flat read
    /// instead of nesting a 3-arm branch inside the layout column.
    @ViewBuilder
    private func body(for viewModel: AISearchViewModel) -> some View {
        if viewModel.thinking {
            ThinkingIndicator()
        } else if let answer = viewModel.answer {
            AnswerBlock(answer: answer,
                        unavailableReason: viewModel.unavailableReason,
                        onTapCitation: onTapCitation)
        } else {
            SuggestionList { suggestion in
                Task { await viewModel.ask(suggestion) }
            }
        }
    }
}
