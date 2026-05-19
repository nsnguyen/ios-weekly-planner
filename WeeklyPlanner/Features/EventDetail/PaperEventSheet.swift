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
    /// Identifier of the event to display. Drives the `.task(id:)` so a
    /// different event tapped while the sheet is open will refetch.
    let eventID: UUID

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
    @State private var dragOffset: CGFloat = 0

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
        .animation(reduceMotion ? .linear(duration: 0) : AnimationTokens.sheetSlide,
                   value: isOpen)
        .task(id: eventID) {
            if viewModel == nil || viewModel?.eventID != eventID {
                let generator = intelligenceService.map {
                    EventSuggestionGenerator(intelligence: $0)
                }
                viewModel = EventDetailViewModel(eventID: eventID,
                                                  eventStore: eventStore,
                                                  suggestionGenerator: generator)
            }
            await viewModel?.load()
            await viewModel?.refreshAISuggestion()
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
            EventHeader(event: viewModel?.event ?? Self.placeholderEvent,
                        onClose: { isOpen = false })

            if let event = viewModel?.event, let viewModel {
                bodyRows(event: event, viewModel: viewModel)
                    .padding(.horizontal, 18)
            } else {
                Spacer()
                    .frame(height: 200)
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

            EventAISticky(suggestion: viewModel.aiSuggestion)
                .padding(.top, 14)

            EventDeleteButton(action: { showDeleteConfirm = true })
                .padding(.top, 14)
                .padding(.bottom, 18)
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
                withAnimation(reduceMotion ? .linear(duration: 0) : AnimationTokens.sheetSlide) {
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
            PaperEventSheet(eventID: eventID, isOpen: $isOpen)
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
