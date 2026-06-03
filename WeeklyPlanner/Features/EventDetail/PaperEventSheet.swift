import SwiftUI

/// The torn-paper bottom sheet that opens when the user taps an event on
/// the Day or Week page. Two-layer composition: a dark backdrop that taps
/// to dismiss, and a cream torn-paper card anchored to the bottom of the
/// screen that slides up over `AnimationTokens.sheetSlide` and accepts a
/// drag-to-dismiss gesture.
///
/// The card carries the same paper chrome as the page itself — red margin
/// line, three hole punches at the top, the radial-gradient paper fill
/// over solid cream — plus a `TornEdgeShape` band at the top that gives
/// the sheet its signature "torn from a notebook" silhouette.
///
/// Inside the card lives the entire detail UI:
///
/// - `EventHeader` — category chip, handwriting title, time line, close
/// - `EventLocationRow` (if `event.location != nil`)
/// - `EventTravelRow` (if `event.travelMinutes != nil`)
/// - `EventAlertRow`
/// - `EventLocationAlertRow`
/// - `EventInviteesRow` (if `event.attendeesCount > 1`)
/// - `EventAISticky` (if the suggestion is non-empty)
/// - `EventDeleteButton`
///
/// The view-model is constructed lazily in `.task(id:)` so the env
/// `eventStore` is available before instantiation. Toggle bindings round-
/// trip through the view-model's `toggleAlert(_:)` / `toggleLocationAlert(_:)`
/// methods so a flip both updates UI state and persists the reminder.
struct PaperEventSheet: View {
    /// What the sheet is showing/doing.
    enum SheetMode: Equatable {
        case view(UUID)
        case edit(UUID)
        case create(at: Date)

        var existingEventID: UUID? {
            switch self {
            case let .view(id), let .edit(id): return id
            case .create: return nil
            }
        }
    }

    /// Initial mode for the sheet. Seeded into `currentMode` on appear
    /// via the `.task(id:)` block. The view never reads `initialMode`
    /// directly after seed — it reads `currentMode`, which can flip
    /// (`.view` ↔ `.edit`) inside the same sheet via the Edit link.
    let initialMode: SheetMode

    /// Mutable mode the sheet actually renders. `nil` before the first
    /// `.task(id:)` fires; the dispatcher treats `nil` as "default to
    /// view-mode placeholder" so the sheet doesn't flash empty.
    @State private var currentMode: SheetMode?

    /// Two-way binding to the sheet's open state. Set to `false` by the
    /// backdrop tap, the close button, drag-to-dismiss, and after a
    /// confirmed delete.
    @Binding var isOpen: Bool

    @Environment(\.eventStore) private var eventStore
    @Environment(\.intelligenceService) private var intelligenceService
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: EventDetailViewModel?
    @State private var showDeleteConfirm = false
    @State private var showCancelConfirm = false
    @State private var dragOffset: CGFloat = 0

    /// Phase 29 (16): the AI "SUGGESTED" sticky is no longer always-on. It
    /// stays hidden until the user taps "Ask AI", then reveals inline. Reset
    /// to `false` whenever a new event is seeded (see `.task(id:)`).
    @State private var showAISuggestion = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if isOpen {
                backdrop
                    .transition(.opacity)

                sheetCard
                    .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
        .animation(AnimationTokens.sheetSlide(reduced: reduceMotion),
                   value: isOpen)
        .task(id: initialMode) {
            // Seed currentMode from the caller's initial intent. Re-seed
            // whenever initialMode changes (e.g., a different event id
            // arrives while the sheet is already on screen).
            currentMode = initialMode
            // A freshly-seeded event starts with the AI suggestion collapsed.
            showAISuggestion = false
            switch initialMode {
            case .view(let id), .edit(let id):
                if viewModel == nil || viewModel?.eventID != id {
                    let generator = intelligenceService.map {
                        EventSuggestionGenerator(intelligence: $0)
                    }
                    viewModel = EventDetailViewModel(eventID: id,
                                                     eventStore: eventStore,
                                                     suggestionGenerator: generator)
                }
                await viewModel?.load()
                await viewModel?.refreshAISuggestion()
                if case .edit = initialMode { viewModel?.beginEditing() }
            case .create(let date):
                if viewModel == nil {
                    viewModel = EventDetailViewModel(eventID: UUID(),
                                                     eventStore: eventStore)
                }
                viewModel?.beginCreating(at: date,
                                         calendar: WeekMath.mondayCalendar())
            }
        }
        .alert("Delete this event?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel?.delete()
                    isOpen = false
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Discard changes?", isPresented: $showCancelConfirm) {
            Button("Discard", role: .destructive) {
                // Dirty cancel: .edit reverts to view; .create dismisses.
                if case .edit = currentMode {
                    revertToView()
                } else {
                    viewModel?.cancelEditing()
                    isOpen = false
                }
            }
            Button("Keep editing", role: .cancel) {}
        }
    }

    // MARK: - Backdrop

    /// Dark scrim covering the full screen. Tap anywhere to dismiss.
    /// Opacity is the spec's `0.45`; the colour itself is fixed black so
    /// it reads the same regardless of theme.
    private var backdrop: some View {
        Color.black
            .opacity(0.45)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                isOpen = false
            }
            .accessibilityLabel("Close event details")
    }

    // MARK: - Sheet card

    /// The torn-paper card. Built bottom-up:
    ///   1. Content `VStack` (header + rows + sticky + delete) is computed
    ///      first so the card's `.background` and torn-edge `.overlay` can
    ///      size to it without re-laying-out the body twice.
    ///   2. Paper background + torn top edge + red margin + hole punches
    ///      are layered as overlays on top of the cream fill.
    ///   3. Corner radius, shadow, and the bottom-edge inset are applied to
    ///      the composed view.
    private var sheetCard: some View {
        cardContent
            .background(paperBackground)
            .overlay(alignment: .top) {
                TornEdgeShape()
                    .fill(theme.cream)
                    .frame(height: 10)
                    .offset(y: -8)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(theme.redLine)
                    .frame(width: 1)
                    .padding(EdgeInsets(top: 14, leading: 32, bottom: 0, trailing: 0))
            }
            .overlay(alignment: .topLeading) {
                holePunches
                    .padding(EdgeInsets(top: 18, leading: 14, bottom: 0, trailing: 0))
            }
            .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 4,
                                                                                bottomLeading: 14,
                                                                                bottomTrailing: 14,
                                                                                topTrailing: 4)))
            .shadow(color: Color.black.opacity(0.5), radius: 15, x: 0, y: -8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 360, alignment: .bottom)
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 32, trailing: 16))
            .offset(y: dragOffset)
            .gesture(dragGesture)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }

    /// Inner content: header on top, body rows below, sticky + delete at
    /// the bottom. Padding mirrors the spec — internal 18pt horizontal
    /// gutter for the row stack, plus the header brings its own 44pt
    /// leading inset that clears the red margin / hole-punch column.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch currentMode {
            case .view, .none:
                EventHeader(event: viewModel?.event ?? Self.placeholderEvent,
                            onClose: { isOpen = false },
                            onEdit: viewModel?.event == nil ? nil : { promoteToEdit() })
                if let event = viewModel?.event, let viewModel {
                    bodyRows(event: event, viewModel: viewModel)
                        .padding(.horizontal, 18)
                } else {
                    Spacer().frame(height: 200)
                }
            case .edit, .create:
                if let viewModel, let composer = viewModel.composer {
                    let isCreate: Bool = { if case .create = currentMode { return true } else { return false } }()
                    let isEdit: Bool = { if case .edit = currentMode { return true } else { return false } }()
                    EditableEventContent(composer: composer,
                                         canSave: composer.canSave,
                                         isCreate: isCreate,
                                         showsDelete: isEdit,
                                         onSave: {
                                             await viewModel.save()
                                             // After save: .edit reverts to view in
                                             // place; .create dismisses (no view to
                                             // revert to).
                                             if isEdit {
                                                 if let id = currentMode?.existingEventID {
                                                     currentMode = .view(id)
                                                 }
                                             } else if viewModel.composer == nil {
                                                 isOpen = false
                                             }
                                         },
                                         onCancel: {
                                             if viewModel.composerIsDirty {
                                                 showCancelConfirm = true
                                             } else if isEdit {
                                                 // Clean cancel from edit → revert.
                                                 revertToView()
                                             } else {
                                                 // Clean cancel from create → dismiss.
                                                 viewModel.cancelEditing()
                                                 isOpen = false
                                             }
                                         },
                                         onDelete: { showDeleteConfirm = true })
                } else {
                    Spacer().frame(height: 200)
                }
            }
        }
    }

    /// All visible body rows + the AI sticky + the delete button. Pulled
    /// out so `cardContent` stays scannable.
    private func bodyRows(event: Event, viewModel: EventDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let location = event.location {
                EventLocationRow(location: location)
            }

            if let travelMinutes = event.travelMinutes {
                EventTravelRow(minutes: travelMinutes)
            }

            EventAlertRow(isOn: Binding(get: { viewModel.alertOn },
                                        set: { newValue in Task { await viewModel.toggleAlert(newValue) } }),
                          minutes: viewModel.alertMinutes)

            EventLocationAlertRow(isOn: Binding(get: { viewModel.locationAlertOn },
                                                set: { newValue in
                                                    Task { await viewModel.toggleLocationAlert(newValue) }
                                                }),
                                  location: event.location)

            if event.attendeesCount > 1 {
                EventInviteesRow(attendeesCount: event.attendeesCount)
            }

            if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty
            {
                EventNotesRow(notes: notes)
            }

            aiSuggestionSection(viewModel: viewModel)
                .padding(.top, 14)

            EventDeleteButton(action: { showDeleteConfirm = true })
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
    }

    /// Phase 29 (16): the AI suggestion is opt-in per-view. Until the user taps
    /// "Ask AI", nothing AI shows; tapping reveals the `EventAISticky` inline
    /// (and is a no-op affordance when there's no suggestion text to give).
    @ViewBuilder
    private func aiSuggestionSection(viewModel: EventDetailViewModel) -> some View {
        if showAISuggestion {
            EventAISticky(suggestion: viewModel.aiSuggestion)
        } else {
            Button {
                withAnimation(AnimationTokens.sheetSlide(reduced: reduceMotion)) {
                    showAISuggestion = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                    Text("Ask AI")
                        .font(font.font(at: 16, weight: .semibold))
                }
                .foregroundStyle(theme.blueInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .dashedBorder(color: theme.blueInk.opacity(0.6), dash: [4, 3],
                          lineWidth: 0.5, cornerRadius: 4)
            .accessibilityLabel("Ask AI for a suggestion")
            .accessibilityIdentifier("paperEventSheet.askAI")
        }
    }

    /// The cream paper fill with the soft radial gradient on top. Matches
    /// the same recipe used by `PaperSurface` so the sheet reads as a
    /// torn-off scrap of the same paper as the page below.
    private var paperBackground: some View {
        ZStack {
            theme.cream
            RadialGradient(gradient: Gradient(stops: [
                .init(color: theme.creamHi, location: 0),
                .init(color: theme.cream.opacity(0.55), location: 0.55),
                .init(color: theme.creamLo, location: 1),
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 360)
        }
    }

    /// The three small hole-punch dots that anchor the sheet to the
    /// "spine" of the book. Spaced 60pt apart along the top.
    private var holePunches: some View {
        HStack(spacing: 50) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Circle()
                    .fill(theme.holePunch)
                    .frame(width: 10, height: 10)
            }
        }
    }

    // MARK: - Mode promotion

    /// View → Edit promotion. Called from the view-mode header's Edit
    /// link. Seeds the composer from the loaded event and flips
    /// `currentMode` so `cardContent` dispatches to the editable variant.
    /// No-op if not currently in `.view` (e.g., we're already editing).
    private func promoteToEdit() {
        guard case let .view(id) = currentMode else { return }
        viewModel?.beginEditing()
        currentMode = .edit(id)
    }

    /// Edit → View revert. Called from Save (after `viewModel.save()`
    /// completes), from clean Cancel, and from the discard-confirmed
    /// dirty Cancel. Clears any composer state and flips `currentMode`
    /// back. No-op if not in `.edit`.
    private func revertToView() {
        guard case let .edit(id) = currentMode else { return }
        viewModel?.cancelEditing()
        currentMode = .view(id)
    }

    // MARK: - Drag-to-dismiss

    /// Vertical drag gesture. Translation tracks the finger live so the
    /// sheet visibly follows; on release, we dismiss if the gesture has
    /// crossed 80pt of pull AND the predicted endpoint is past 100pt
    /// (rough velocity proxy — matches the spec's "velocity.y > 200").
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let didDrag = value.translation.height > 80
                let willCoast = value.predictedEndTranslation.height > 100
                if didDrag, willCoast {
                    isOpen = false
                }
                withAnimation(AnimationTokens.sheetSlide(reduced: reduceMotion)) {
                    dragOffset = 0
                }
            }
    }

    // MARK: - Placeholder

    /// Empty placeholder event used while the view-model is still loading.
    /// The view shows the header skeleton for one frame before `load()`
    /// completes; we render an invisible-ish title so the layout doesn't
    /// jump.
    private static let placeholderEvent = Event(title: " ",
                                                start: Date(),
                                                end: Date(),
                                                category: .personal)
}

// MARK: - Previews

#Preview("PaperEventSheet · Cream") {
    PaperEventSheetPreviewHost()
        .paperTheme(.cream)
}

/// Internal preview host that stands up an in-memory `EventStoring` and
/// opens the sheet against a seeded event so the canvas renders the full
/// composition.
private struct PaperEventSheetPreviewHost: View {
    @State private var isOpen = true
    private let eventID = UUID()
    private let store = PreviewSeededStore()

    init() {
        let calendar = WeekMath.mondayCalendar()
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 20
        let eightPM = calendar.date(from: components) ?? Date()
        let event = Event(id: eventID,
                          title: "Sara's birthday",
                          start: eightPM,
                          end: calendar.date(byAdding: .hour, value: 3, to: eightPM) ?? eightPM,
                          location: "Trick Dog, Mission",
                          category: .family,
                          attendeesCount: 4,
                          travelMinutes: 22)
        store.seed(event)
    }

    var body: some View {
        ZStack {
            BookCover()
            PaperEventSheet(initialMode: .view(eventID), isOpen: $isOpen)
        }
        .environment(\.eventStore, store)
    }
}

/// Minimal `EventStoring` that holds a single in-memory event. Used only by
/// the preview above so the sheet renders without a SwiftData container.
@MainActor
private final class PreviewSeededStore: EventStoring {
    private var stored: Event?

    nonisolated init() {}

    func seed(_ event: Event) {
        stored = event
    }

    func events(forWeekOffset _: Int, today _: Date) async throws -> [Event] {
        stored.map { [$0] } ?? []
    }

    func event(id: UUID) async throws -> Event? {
        stored?.id == id ? stored : nil
    }

    func upsert(_ event: Event) async throws {
        stored = event
    }

    func delete(id _: UUID) async throws {
        stored = nil
    }

    func events(matching _: EventQuery) async throws -> [Event] {
        stored.map { [$0] } ?? []
    }
}
