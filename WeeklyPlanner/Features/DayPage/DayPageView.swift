import SwiftUI

/// The flip-aware Day page surface. Draws the side-tab column on the leading
/// edge, attaches the horizontal-swipe gesture, and delegates the actual paper
/// rendering to `DayPageContent` via `PageFlipContainer`.
///
/// `DayPageView` does **not** own the `PageFlipController` — `RootView` does,
/// and the controller is passed in so the top bar and the page-flip surface
/// share a single source of truth. Side-tab taps and swipe gestures still
/// flow through the controller; the only difference from earlier phases is
/// the lifecycle (controller now outlives this view's identity, which lets
/// the Day/Week toggle in Group T swap render trees without resetting the
/// current page).
///
/// `PageFlipController` is `@Observable`, so SwiftUI tracks reads of
/// `controller.current` automatically — passing the controller as a `let`
/// property is sufficient to re-render the view tree on each flip.
///
/// Layout:
/// - `PageFlipContainer` fills the available space; inside it, each rendered
///   `DayPageContent` brings its own paper-page chrome.
/// - `SideTabs` is laid out beside the flip surface so the rounded tabs poke
///   past the leading edge of the page.
struct DayPageView: View {
    /// Shared controller injected by `RootView`. Drives both this view's
    /// side-tab selection / swipe gesture and the top bar's week chevrons.
    let controller: PageFlipController

    @Environment(\.paperTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dtSize

    /// Construct a `DayPageView` over the supplied (shared) controller.
    init(controller: PageFlipController) {
        self.controller = controller
    }

    var body: some View {
        let now = Date()
        let weekDays = WeekMath.weekDays(forOffset: controller.current.week, today: now)
        let currentWeekDays = WeekMath.weekDays(forOffset: 0, today: now)
        let todayIdx = WeekMath.todayIndex(in: currentWeekDays, for: now)
        let isCurrentWeek = controller.current.week == 0

        return HStack(alignment: .top, spacing: 4) {
            PageFlipContainer(controller: controller) { coord in
                DayPageContent(weekOffset: coord.week, dayIdx: coord.day)
            }
            .horizontalSwipe { direction in
                controller.flipDay(direction: direction)
            }

            SideTabs(weekDays: weekDays,
                     selectedIdx: controller.current.day,
                     todayIdx: isCurrentWeek ? todayIdx : nil,
                     onSelect: { idx in controller.flipToDay(idx: idx) })
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// The composite Day Page view: paper book chrome + ruled lines + red margin
/// + hole punches + header + events list + inbox block + to-do patch +
/// page-number footer for a single `(weekOffset, dayIdx)` cell.
///
/// Renders ONE static day page — `DayPageView` wraps several of these in
/// `PageFlipContainer` to animate between days. Owns a `DayPageViewModel`
/// instance for `(weekOffset, dayIdx)` and refreshes it once on `.task`;
/// real-time observation is deferred to a later phase when SwiftData `@Model`
/// values are Sendable across actors.
///
/// Tokens flow in from `@Environment(\.paperTheme)`, `\.paperFont`, and
/// `\.paperSize`; the three stores are pulled from `@Environment` as well so
/// previews can inject `StubEventStore` / `StubInboxStore` / `StubTaskStore`
/// without standing up a real SwiftData container.
struct DayPageContent: View {
    /// Week relative to today's week (0 = current). Forwarded to the view model.
    let weekOffset: Int

    /// Monday-based index within the week (0 = Mon … 6 = Sun). Forwarded to
    /// the view model and used to pick the right `WeekDay` for the header.
    let dayIdx: Int

    @Environment(\.eventStore) private var eventStore
    @Environment(\.inboxStore) private var inboxStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.intelligenceService) private var intelligenceService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.inboxSyncEngine) private var inboxSyncEngine
    @Environment(\.deepLinkRouter) private var deepLinkRouter

    /// Lazily-instantiated view model; nil until `.task` runs once on first
    /// appear, at which point we create it and call `refresh()`.
    @State private var viewModel: DayPageViewModel?

    /// Identifier of the event whose detail sheet is currently open. `nil`
    /// when no sheet is presented. Tapping any `EventEntryRow` sets this.
    @State private var openEventID: UUID?

    var body: some View {
        let now = Date()
        let days = WeekMath.weekDays(forOffset: weekOffset, today: now)
        let weekDay = days.indices.contains(dayIdx) ? days[dayIdx] : days[0]
        let weekMeta = WeekMath.weekMeta(forOffset: weekOffset, today: now)

        return ZStack {
            BookPage {
                PaperSurface {
                    ZStack(alignment: .topLeading) {
                        PaperGrain()
                        RuledLines()
                        RedMarginLine()
                        HolePunches()

                        ScrollView {
                            content(weekDay: weekDay, weekMeta: weekMeta)
                                .padding(.top, 18)
                                .padding(.leading, 44)
                                .padding(.trailing, 18)
                                .padding(.bottom, 18)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .overlay(alignment: .topTrailing) {
                                    stickyNoteOverlay
                                }
                        }
                        .refreshable {
                            await viewModel?.refresh(via: inboxSyncEngine)
                        }

                        PageNumber(date: weekDay.date)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
            }

            if let id = openEventID {
                PaperEventSheet(eventID: id,
                                isOpen: Binding(get: { openEventID != nil },
                                                set: { if !$0 { openEventID = nil } }))
            }
        }
        .task {
            if viewModel == nil {
                let generator = intelligenceService.map {
                    StickyInsightGenerator(intelligence: $0)
                }
                viewModel = DayPageViewModel(weekOffset: weekOffset,
                                             dayIdx: dayIdx,
                                             eventStore: eventStore,
                                             inboxStore: inboxStore,
                                             taskStore: taskStore,
                                             stickyGenerator: generator,
                                             modelContext: modelContext)
            }
            await viewModel?.refresh()
        }
        .onChange(of: deepLinkRouter.pending) { _, new in
            guard case let .event(id) = new else { return }
            openEventID = id
            deepLinkRouter.consume()
        }
    }

    // MARK: - Subviews

    /// Top-right AI sticky note, gated on the presence of a non-dismissed
    /// `AIInsight` row for this `(weekOffset, dayIdx)` cell. Padded 16pt off
    /// the page's top/trailing edges so the masking-tape overhang stays
    /// inside the paper. If no insight exists the overlay collapses to an
    /// `EmptyView` and the corner is left blank — the design treats absent
    /// stickies as "no note today", not "blank placeholder".
    @ViewBuilder
    private var stickyNoteOverlay: some View {
        if let insight = StickyNoteGenerator.insight(forWeekOffset: weekOffset,
                                                     dayIdx: dayIdx,
                                                     in: modelContext)
        {
            AIStickyNote(insight: insight)
                .padding(.top, 96)
                .padding(.trailing, 16)
        }
    }

    /// Content column: header, optional events list, optional inbox block,
    /// optional to-do patch, or the empty-state hint when all three are
    /// empty. Split out so `body` stays readable.
    private func content(weekDay: WeekDay, weekMeta: WeekMeta) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DayPageHeader(weekDay: weekDay,
                          weekMeta: weekMeta,
                          isToday: viewModel?.isToday ?? false)

            Spacer().frame(height: 8)

            if let viewModel {
                let hasEvents = !viewModel.events.isEmpty
                let hasInbox = !viewModel.inbox.isEmpty
                let hasTasks = !viewModel.tasks.isEmpty

                if hasEvents {
                    EventEntryList(events: viewModel.events, onTap: { event in
                        openEventID = event.id
                    })
                }

                if hasInbox {
                    InboxBlock(suggestions: viewModel.inbox,
                               onAccept: { id in
                                   Task { await viewModel.accept(suggestionID: id) }
                               },
                               onDismiss: { id in
                                   Task { await viewModel.dismiss(suggestionID: id) }
                               })
                }

                if hasTasks {
                    TodoBlock(tasks: viewModel.tasks) { id in
                        Task { await viewModel.toggleTask(id: id) }
                    }
                    .padding(.top, 12)
                }

                if !hasEvents, !hasInbox, !hasTasks {
                    EmptyDayState()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("DayPageView · Today (stub stores)") {
    let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
    return DayPageView(controller: controller)
        .environment(\.eventStore, StubEventStore())
        .environment(\.inboxStore, StubInboxStore())
        .environment(\.taskStore, StubTaskStore())
        .paperTheme(.cream)
}

#Preview("DayPageContent · Today (stub stores)") {
    ZStack {
        BookCover()
        DayPageContent(weekOffset: 0, dayIdx: 5)
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
    }
    .environment(\.eventStore, StubEventStore())
    .environment(\.inboxStore, StubInboxStore())
    .environment(\.taskStore, StubTaskStore())
    .paperTheme(.cream)
}
