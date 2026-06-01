import SwiftUI
import SwiftData
import Combine

/// Root composition for the paper app. Sits above `RootView` (which only
/// hosts the environment values) and below every page. Owns:
///
/// - `TabSelection` — which of Calendar / Review / Settings is active.
/// - `PageFlipController` + `paperView` — the Day-vs-Week state shared
///   inside the Calendar tab (lifted from `RootView` so a tab switch
///   doesn't reset the Day page's focused day or week offset).
/// - Modal-overlay flags — `isPickerOpen`, `isAISearchOpen` — also lifted
///   from `RootView` so the overlays render above both the active tab's
///   content and the bottom tab bar.
///
/// Renders a persistent `BookCover` at z=0 so tab switches cross-fade the
/// inside-the-book content without re-mounting the leather. The active tab
/// content layers on top with a 0.18s opacity transition; the
/// `PaperTabBar` pins to the bottom via `.safeAreaInset(edge: .bottom)`
/// so the active tab can use the full inner area and modal overlays float
/// above both layers.
struct AppShell: View {
    @Environment(\.eventStore) private var eventStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.inboxStore) private var inboxStore
    @Environment(\.inboxSyncEngine) private var inboxSyncEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.deepLinkRouter) private var deepLinkRouter

    @Query private var settingsRows: [UserSettings]

    @State private var selection: TabSelection
    @State private var controller: PageFlipController
    @State private var paperView: PaperView = .day
    @State private var isPickerOpen: Bool = false
    @State private var isAISearchOpen: Bool = false

    /// Phase 24 — constructed once at `init` so the orchestrator's per-day
    /// TTL cache survives view re-renders. Computing a fresh orchestrator
    /// in the env-injection chain would defeat the cache (each render =
    /// new instance = empty cache).
    ///
    /// **Why eager-init in `init` instead of `.task`** — SwiftUI does not
    /// guarantee parent/child `.task` ordering. With a `.task`-based lazy
    /// init, `DayPageView.task` could fire before `AppShell.task`,
    /// capturing a nil orchestrator that the VM never re-captures (the
    /// VM's `private let orchestrator` is set once at init). Constructing
    /// here in `init` makes the env value non-nil from the very first
    /// render, eliminating the race.
    @State private var stickyOrchestrator: StickyOrchestrator

    /// The current settings row, or a fresh default if SwiftData hasn't
    /// materialized one yet. `@Query` returns at most one element here
    /// because `SwiftDataSettingsStore.current()` lazy-creates exactly one
    /// `UserSettings` instance.
    private var settings: UserSettings { settingsRows.first ?? UserSettings() }

    private var resolvedTheme: PaperTheme { settings.paperTheme.theme }
    private var resolvedFont: PaperFont { settings.paperFont }
    private var resolvedSize: PaperSize { settings.paperSize }

    init(settingsStore: any SettingsStoring) {
        let today = Date()
        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0
        _controller = State(initialValue: PageFlipController(current: PageCoordinate(week: 0,
                                                                                     day: todayIdx)))
        _selection = State(initialValue: TabSelection(settings: settingsStore))
        _stickyOrchestrator = State(initialValue: AppShell.makeStickyOrchestrator())
    }

    var body: some View {
        ZStack {
            BookCover()

            Group {
                switch selection.current {
                case .calendar:
                    calendarTab
                case .review:
                    PaperReviewView(weekOffset: controller.current.week)
                case .settings:
                    PaperSettingsView()
                }
            }
            .transition(.opacity)
            .animation(reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.18),
                       value: selection.current)

            WeekPickerSheet(isOpen: $isPickerOpen,
                            initialWeekOffset: controller.current.week)
            { offset in
                controller.setWeek(offset)
                isPickerOpen = false
            }

            if isAISearchOpen {
                PaperAISearchView(isOpen: $isAISearchOpen,
                                  eventStore: eventStore,
                                  intelligence: makeIntelligenceService(),
                                  onTapCitation: { _ in
                                      // Phase 12 closes the overlay; routing the
                                      // citation tap to the matching event detail
                                      // sheet stays out of scope until the shared
                                      // event-detail router lands.
                                  })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gmailDidConnect)) { _ in
            let engine = inboxSyncEngine
            Task { @MainActor in
                _ = try? await engine?.sync(now: Date())
            }
        }
        .onChange(of: deepLinkRouter.pending) { _, new in
            guard new != nil else { return }
            selection.current = .calendar
            // DayPageView consumes the router itself; we just make sure the
            // calendar tab is visible.
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaperTabBar(selection: Binding(
                get: { selection.current },
                set: { selection.current = $0 }
            ))
        }
        .animation(AnimationTokens.aiOverlaySlide(reduced: reduceMotion),
                   value: isAISearchOpen)
        .environment(\.intelligenceService, makeIntelligenceService())
        .environment(\.stickyOrchestrator, stickyOrchestrator)
        .paperTheme(resolvedTheme)
        .paperFont(resolvedFont)
        .paperSize(resolvedSize)
    }

    @ViewBuilder
    private var calendarTab: some View {
        let today = Date()
        let currentWeek = controller.current.week
        let weekMeta = WeekMath.weekMeta(forOffset: currentWeek, today: today)
        let isCurrentWeek = currentWeek == 0
        let currentWeekDays = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: currentWeekDays, for: today)
        let isOnTodayPage = isCurrentWeek && controller.current.day == todayIdx

        BookContainer(paperView: $paperView,
                      weekMeta: weekMeta,
                      isOnTodayPage: isOnTodayPage,
                      isPickerOpen: isPickerOpen,
                      onOpenAI: { isAISearchOpen = true },
                      onOpenPicker: { isPickerOpen.toggle() },
                      onJumpToday: {
                          if let idx = todayIdx {
                              controller.setWeek(0)
                              controller.flipToDay(idx: idx)
                          }
                      },
                      onPrevWeek: {
                          // Both Day and Week views jump the week instantly via
                          // setWeek. The Week view has no PageFlipContainer to
                          // drive commit(), so the old `flipWeek` path set
                          // `target` with no committer and permanently stranded
                          // `isFlipping` — the Phase 27 freeze. setWeek mutates
                          // `current` directly and can never strand.
                          controller.setWeek(controller.current.week - 1)
                      },
                      onNextWeek: {
                          controller.setWeek(controller.current.week + 1)
                      },
                      onPrevDay: { controller.flipDay(direction: .prev) },
                      onNextDay: { controller.flipDay(direction: .next) },
                      content: {
                          switch paperView {
                          case .day:
                              DayPageView(controller: controller)
                          case .week:
                              WeekPageView(weekOffset: controller.current.week)
                                  // Fresh identity per offset so the week's view
                                  // model reloads its events when the user jumps
                                  // weeks — otherwise the picker shows the prior
                                  // week's events (Phase 27 / suggestion 22).
                                  // Mirrors DayPageContent's `.id(coord)`.
                                  .id(controller.current.week)
                          }
                      },
                      includesCover: false)
    }

    private func makeIntelligenceService() -> any IntelligenceService {
        let registry = ToolRegistry(events: eventStore, tasks: taskStore, inbox: inboxStore)
        let fallback = StubIntelligenceService(eventStore: eventStore)
        return PlannerLanguageModel(registry: registry, fallback: fallback)
    }

    /// Phase 24 — builds the sticky cascade. The orchestrator owns its own
    /// per-day TTL cache so it must be constructed once and reused. The
    /// `EncouragementInsightGenerator` fallback guarantees the cascade
    /// always emits at least one insight, matching the Phase 13 behaviour
    /// the view layer was already designed around.
    ///
    /// **Static** because this is called from `init`, where `self` (and
    /// therefore the `@Environment` stores) is not yet available. The
    /// encouragement fallback's `IntelligenceService` is built from stub
    /// stores — that's intentional and safe because the encouragement
    /// prompt inlines today's events into the prompt string itself (see
    /// `EncouragementInsightGenerator.prompt(weekOffset:dayIdx:events:)`)
    /// rather than calling tools that would read the stores at run time.
    /// The four *primary* generators (Travel / Weather / Keyword / Inbox)
    /// don't depend on the SwiftData stores at all — they read everything
    /// they need from the `DayContext` passed into `generate(for:)`.
    private static func makeStickyOrchestrator() -> StickyOrchestrator {
        let registry = ToolRegistry(events: StubEventStore(),
                                    tasks: StubTaskStore(),
                                    inbox: StubInboxStore())
        let fallbackService = StubIntelligenceService(eventStore: StubEventStore())
        let intelligence: any IntelligenceService = PlannerLanguageModel(
            registry: registry, fallback: fallbackService)
        let generators: [any InsightGenerator] = [
            TravelInsightGenerator(provider: LiveTravelProvider()),
            WeatherInsightGenerator(provider: LiveWeatherProvider()),
            KeywordInsightGenerator(model: LiveKeywordInsightModel()),
            InboxInsightGenerator(),
        ]
        return StickyOrchestrator(
            generators: generators,
            fallback: EncouragementInsightGenerator(intelligence: intelligence))
    }

}
