import SwiftUI

/// The root scene the user lands on when the app launches. Owns the top-level
/// navigation state — `PageFlipController` (which week / day is on screen),
/// the Day-vs-Week `paperView` toggle, the `isPickerOpen` flag for the week
/// picker, and the `isAISearchOpen` flag for the Apple Intelligence overlay.
///
/// Lays out a single `BookContainer` for the leather chrome and supplies
/// either a `DayPageView` or a `WeekPageView` as its content, picked by the
/// `paperView` toggle. Wires the container's nav callbacks back to the
/// controller:
///
/// - Top-bar week chevrons: instant `setWeek` in Day view, 3D `flipWeek` in
///   Week view (matches the Phase 09 spec's "chevron behavior split").
/// - Top-bar Today pill: hops `setWeek(0)` then animates to today's weekday
///   via `flipToDay(idx:)`.
/// - Bottom-controls day chevrons: animated `flipDay(direction:)`.
/// - Top-bar AI button: opens the `PaperAISearchView` overlay (Phase 12).
///
/// Citation taps inside the AI overlay close the overlay and surface the
/// matched event's `id` back to `RootView`. Phase 12 stops there — opening
/// the matching event detail sheet is left to a future phase that wires a
/// shared event-detail router (Day and Week pages each own their own
/// `openEventID` today, with no global routing). For now the user can find
/// the cited event manually on the day page underneath.
struct RootView: View {
    /// Source-of-truth for which page is on screen. Owned by `RootView` (not
    /// `DayPageView`) so the top bar and the page-flip surface share one
    /// controller and the user keeps their position when the Day/Week toggle
    /// is wired in Group T.
    @State private var controller: PageFlipController

    /// Day-vs-Week spread selector. Drives the Day/Week toggle and the
    /// top-bar / bottom-controls week-vs-day routing.
    @State private var paperView: PaperView = .day

    /// True while the week picker overlay is open. Currently toggled by the
    /// `DateRangePill` tap; Group R replaces the no-op overlay with the real
    /// picker sheet.
    @State private var isPickerOpen: Bool = false

    /// True while the Apple Intelligence overlay is open. Flipped by the
    /// top-bar AI button and by `PaperAISearchView`'s own Close path.
    @State private var isAISearchOpen: Bool = false

    /// Direct read of the env-injected event store. `PaperAISearchView`
    /// needs a concrete `EventStoring` at init time to build its
    /// `AISearchViewModel`, so we forward this value at the call site
    /// rather than relying on a child-only `@Environment` read.
    @Environment(\.eventStore) private var eventStore

    /// Same forwarding as `eventStore` — Phase 13's `ToolRegistry` needs
    /// task + inbox stores so the model can answer questions across all
    /// three data sources without reaching back into singletons.
    @Environment(\.taskStore) private var taskStore
    @Environment(\.inboxStore) private var inboxStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        let today = Date()
        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0
        _controller = State(initialValue: PageFlipController(current: PageCoordinate(week: 0,
                                                                                     day: todayIdx)))
    }

    var body: some View {
        let today = Date()
        let currentWeek = controller.current.week
        let weekMeta = WeekMath.weekMeta(forOffset: currentWeek, today: today)
        let isCurrentWeek = currentWeek == 0
        let currentWeekDays = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: currentWeekDays, for: today)
        let isOnTodayPage = isCurrentWeek && controller.current.day == todayIdx

        return ZStack {
            BookContainer(paperView: $paperView,
                          weekMeta: weekMeta,
                          isOnTodayPage: isOnTodayPage,
                          isPickerOpen: isPickerOpen,
                          onOpenAI: {
                              isAISearchOpen = true
                          },
                          onOpenPicker: {
                              isPickerOpen.toggle()
                          },
                          onJumpToday: {
                              if let idx = todayIdx {
                                  controller.setWeek(0)
                                  controller.flipToDay(idx: idx)
                              }
                          },
                          onPrevWeek: {
                              if paperView == .day {
                                  controller.setWeek(controller.current.week - 1)
                              } else {
                                  controller.flipWeek(direction: .prev)
                              }
                          },
                          onNextWeek: {
                              if paperView == .day {
                                  controller.setWeek(controller.current.week + 1)
                              } else {
                                  controller.flipWeek(direction: .next)
                              }
                          },
                          onPrevDay: { controller.flipDay(direction: .prev) },
                          onNextDay: { controller.flipDay(direction: .next) },
                          content: {
                              switch paperView {
                              case .day:
                                  DayPageView(controller: controller)
                              case .week:
                                  WeekPageView(weekOffset: controller.current.week)
                              }
                          })

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
                                      // Phase 12 closes the overlay and stops
                                      // there — routing the citation tap to
                                      // the matching event detail sheet
                                      // needs a global router we haven't
                                      // built (Day and Week each own their
                                      // own `openEventID`). The user can
                                      // find the cited event on the page
                                      // underneath.
                                  })
            }
        }
        .animation(reduceMotion ? .linear(duration: 0) : AnimationTokens.sheetSlide,
                   value: isAISearchOpen)
    }

    /// Builds a fresh `PlannerLanguageModel` for the AI overlay. Constructed
    /// inline on demand (and not held on the view) because the overlay is
    /// the only consumer in Phase 13-a, and a per-open session keeps the
    /// model's working state from spanning open / close cycles. The
    /// `settings` closure returns `true` for now; Phase 16 will swap this
    /// for a live read of `UserSettings.appleIntelligenceEnabled`.
    private func makeIntelligenceService() -> any IntelligenceService {
        let registry = ToolRegistry(events: eventStore, tasks: taskStore, inbox: inboxStore)
        let fallback = StubIntelligenceService(eventStore: eventStore)
        return PlannerLanguageModel(registry: registry, fallback: fallback)
    }
}

#Preview {
    RootView()
        .environment(\.eventStore, StubEventStore())
        .environment(\.inboxStore, StubInboxStore())
        .environment(\.taskStore, StubTaskStore())
}
