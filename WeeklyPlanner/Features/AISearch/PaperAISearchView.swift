import SwiftUI

/// The root container for the Apple Intelligence overlay. Stacks the
/// chrome `AISearchTopBar` over the inner `AISearchPaperSheet` on a full-
/// bleed `theme.bookCover` background. Owns the `AISearchViewModel` for
/// its lifetime via `@State` so the model survives any parent re-render
/// while the overlay is open.
///
/// Open / close is driven by the `isOpen` binding the caller passes in.
/// When the binding flips to `false`, the overlay slides off the top edge
/// (or crossfades, under reduce-motion) via the asymmetric transition
/// declared in `transitionInsertion` / `transitionRemoval`. The animation
/// itself is applied by the parent — it owns the `if isOpen { … }` branch
/// and therefore controls the transition's animation. See
/// `RootView.body` for the call site.
///
/// `closeOverlay(completion:)` is the single dismissal codepath. The view
/// flips `isOpen` immediately, then — if a completion was provided —
/// schedules it 100ms later. The delay matches the JS mock's timing and
/// prevents a citation tap from racing the slide-down with a sheet slide-
/// up: by the time `completion` fires, the overlay is visually gone.
struct PaperAISearchView: View {
    /// Two-way binding to the overlay's open state. Set to `false` by the
    /// top-bar Close button and by the citation-tap path.
    @Binding var isOpen: Bool

    /// Forwarded to `AnswerBlock` via `AISearchPaperSheet`. The host
    /// receives the citation event's `id` after the overlay has finished
    /// closing. Phase 12 does not auto-open the matching event — the view
    /// simply closes the overlay and the user finds the event on the day
    /// page underneath. (Phase 13's review wires the global event-detail
    /// router.)
    var onTapCitation: (UUID) -> Void

    @State private var viewModel: AISearchViewModel

    @Environment(\.paperTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Designated initializer. Builds the `AISearchViewModel` eagerly off
    /// the supplied `eventStore` so citation resolution can run on the
    /// model's first `ask(text:)`. Phase 13 wires the live
    /// `IntelligenceService` here; pass the host's
    /// `PlannerLanguageModel` in production and a stub in previews.
    init(isOpen: Binding<Bool>,
         eventStore: any EventStoring,
         intelligence: any IntelligenceService,
         onTapCitation: @escaping (UUID) -> Void)
    {
        _isOpen = isOpen
        _viewModel = State(initialValue: AISearchViewModel(
            eventStore: eventStore,
            intelligence: intelligence
        ))
        self.onTapCitation = onTapCitation
    }

    var body: some View {
        ZStack(alignment: .top) {
            theme.bookCover
                .ignoresSafeArea()

            VStack(spacing: 0) {
                AISearchTopBar(onClose: { closeOverlay() })

                AISearchPaperSheet(viewModel: viewModel,
                                   onTapCitation: { id in
                                       closeOverlay {
                                           onTapCitation(id)
                                       }
                                   })
            }
        }
        .transition(.asymmetric(insertion: transitionInsertion,
                                removal: transitionRemoval))
    }

    /// Closes the overlay. If `completion` is provided, schedules it 100ms
    /// after the close so the slide-down has visibly started by the time
    /// the caller's follow-up modal animates in.
    private func closeOverlay(completion: (() -> Void)? = nil) {
        isOpen = false
        if let completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                completion()
            }
        }
    }

    /// Slide-down + fade insertion, or plain opacity under reduce-motion.
    /// The actual `Animation` curve (`AnimationTokens.sheetSlide`) is
    /// applied by the parent that owns the `if isOpen` branch.
    private var transitionInsertion: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .move(edge: .top).combined(with: .opacity)
    }

    /// Mirror of `transitionInsertion` for removal — same edge so the
    /// overlay un-slides the way it came in.
    private var transitionRemoval: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .move(edge: .top).combined(with: .opacity)
    }
}
