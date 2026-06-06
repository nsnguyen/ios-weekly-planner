import SwiftUI
import UIKit

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
            .environment(controller)
            .horizontalSwipe { direction in
                guard !controller.stickyDragActive else { return }
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
    @Environment(\.stickyOrchestrator) private var stickyOrchestrator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.inboxSyncEngine) private var inboxSyncEngine
    @Environment(\.deepLinkRouter) private var deepLinkRouter
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.paperTheme) private var theme

    /// Lazily-instantiated view model; nil until `.task` runs once on first
    /// appear, at which point we create it and call `refresh()`.
    @State private var viewModel: DayPageViewModel?

    /// Identifier of the event whose detail sheet is currently open. `nil`
    /// when no sheet is presented. Tapping any `EventEntryRow` sets this.
    @State private var openEventID: UUID?

    /// Start of the specific (possibly recurring) occurrence the user tapped.
    /// Threaded into the sheet so "delete this occurrence" targets the right
    /// instance (Phase 35).
    @State private var openEventOccurrenceStart: Date?

    @State private var creatingEventAt: Date?

    /// Identifier of the event currently open for editing via long-press →
    /// Edit. `nil` when no edit sheet is presented. Distinct from
    /// `openEventID` so a tap-to-view and a long-press-to-edit don't fight
    /// over the same binding.
    @State private var editingEventID: UUID?

    @State private var editingTaskID: UUID?

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
                                // Phase 29 (7): header sits higher; the
                                // events/notes area gains ~10pt of vertical
                                // space (was 18).
                                .padding(.top, 8)
                                .padding(.leading, 44)
                                .padding(.trailing, 18)
                                .padding(.bottom, 18)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .overlay(alignment: .topTrailing) {
                                    stickyNoteOverlay
                                }
                                // Tap on empty paper *between* events /
                                // inbox rows commits the pending to-do.
                                // SwiftUI only fires this when no child
                                // (Button, TextField) claims the tap, so
                                // the event-row Buttons still work
                                // normally — those have their own
                                // commitPendingTaskIfAny() calls.
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    commitPendingTaskIfAny()
                                }
                        }
                        .refreshable {
                            await viewModel?.refresh(via: inboxSyncEngine)
                        }
                        .accessibilityRotor("Events") {
                            ForEach(viewModel?.events ?? [], id: \.id) { event in
                                AccessibilityRotorEntry(event.title, id: event.id)
                            }
                        }
                        // Drag-down on the page progressively dismisses
                        // the keyboard, which trips the to-do composer's
                        // blur handler. Standard iOS gesture; works the
                        // same on simulator and device.
                        .scrollDismissesKeyboard(.interactively)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            bottomAffordances(weekDay: weekDay)
                        }

                        // Phase 29 (8): the bottom-right page-number/date
                        // footer is removed — it duplicated the header date
                        // and ate corner space. (PageNumber stays for the
                        // Week page; only the Day page drops it.)
                    }
                }
            }

            if let id = openEventID {
                PaperEventSheet(initialMode: .view(id),
                                occurrenceStart: openEventOccurrenceStart,
                                isOpen: Binding(get: { openEventID != nil },
                                                set: { if !$0 { openEventID = nil; openEventOccurrenceStart = nil } }))
            }
            if let anchor = creatingEventAt {
                PaperEventSheet(initialMode: .create(at: anchor),
                                isOpen: Binding(get: { creatingEventAt != nil },
                                                set: { if !$0 { creatingEventAt = nil } }))
            }
            if let id = editingEventID {
                PaperEventSheet(initialMode: .edit(id),
                                isOpen: Binding(get: { editingEventID != nil },
                                                set: { if !$0 { editingEventID = nil } }))
            }
            if let id = editingTaskID,
               let task = viewModel?.tasks.first(where: { $0.id == id })
            {
                Color.clear
                    .frame(width: 0, height: 0)
                    .popover(isPresented: Binding(get: { editingTaskID != nil },
                                                  set: { if !$0 { editingTaskID = nil } }),
                             attachmentAnchor: .point(.center),
                             arrowEdge: .top)
                    {
                        TaskMiniPopover(task: task,
                                        onPriorityChange: { newPriority in
                                            Task {
                                                await viewModel?.updateTask(id: id) {
                                                    $0.priority = newPriority
                                                }
                                            }
                                        },
                                        onDueChange: { newDue in
                                            Task {
                                                await viewModel?.updateTask(id: id) {
                                                    $0.due = newDue
                                                }
                                            }
                                        },
                                        onDelete: {
                                            Task {
                                                await viewModel?.deleteTask(id: id)
                                                editingTaskID = nil
                                            }
                                        },
                                        onDismiss: { editingTaskID = nil })
                    }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = DayPageViewModel(weekOffset: weekOffset,
                                             dayIdx: dayIdx,
                                             eventStore: eventStore,
                                             inboxStore: inboxStore,
                                             taskStore: taskStore,
                                             orchestrator: stickyOrchestrator,
                                             modelContext: modelContext,
                                             settingsStore: settingsStore)
            }
            await viewModel?.refresh()
        }
        .onChange(of: deepLinkRouter.pending) { _, new in
            guard case let .event(id) = new else { return }
            openEventID = id
            deepLinkRouter.consume()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventStoreDidChange)) { _ in
            Task { await viewModel?.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskStoreDidChange)) { _ in
            Task { await viewModel?.refresh() }
        }
    }

    // MARK: - Subviews

    /// Top-right AI sticky note, gated on the presence of a non-dismissed
    /// `AIInsight` row for this `(weekOffset, dayIdx)` cell. Padded 16pt off
    /// the page's top/trailing edges so the masking-tape overhang stays
    /// inside the paper. If no insight exists the overlay collapses to an
    /// `EmptyView` and the corner is left blank — the design treats absent
    /// stickies as "no note today", not "blank placeholder".
    /// Notes-style "tap outside to lock in" — call from any interactive
    /// tap target in the events / inbox / event-add area when the
    /// to-do composer is active. Asks the composer to relinquish focus;
    /// the TodoAddRow's existing `.onChange(of: composer.pendingBlurToken)`
    /// handler then trips its commit-or-exit branch on the next runloop.
    /// No-op when the composer isn't composing.
    private func commitPendingTaskIfAny() {
        guard viewModel?.taskComposer.isComposing == true else { return }
        viewModel?.taskComposer.requestBlur()
    }

    /// Bottom-pinned affordance stack: `EventAddRow` directly above the
    /// always-visible `TodoBlock`. Both anchor to the bottom of the
    /// visible PaperSurface via `.safeAreaInset(edge: .bottom)` on the
    /// ScrollView so they remain reachable even when the events list
    /// overflows (the events scroll above this stack, not behind it).
    /// Matches the paper-planner mock: "add another" line sits just above
    /// the dashed yellow to-do patch, both with the same 44pt leading /
    /// 18pt trailing page margin and 24pt bottom inset above the
    /// `PageNumber` footer.
    @ViewBuilder
    private func bottomAffordances(weekDay: WeekDay) -> some View {
        if let viewModel {
            let hasEvents = !viewModel.events.isEmpty
            let hasInbox = !viewModel.inbox.isEmpty
            VStack(alignment: .leading, spacing: 8) {
                EventAddRow(isFirstEntry: !hasEvents && !hasInbox) {
                    commitPendingTaskIfAny()
                    creatingEventAt = weekDay.date
                }
                .padding(.leading, 44)
                .padding(.trailing, 18)

                TodoBlock(tasks: viewModel.tasks,
                          composer: viewModel.taskComposer,
                          onToggle: { id in
                              Task { await viewModel.toggleTask(id: id) }
                          },
                          onAddTask: {
                              await viewModel.addTask()
                          },
                          onDelete: { id in
                              Task { await viewModel.deleteTask(id: id) }
                          },
                          onLongPress: { id in
                              editingTaskID = id
                          })
                    .padding(.leading, 44)
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
            }
            .background(theme.cream)
            // Tap-outside-to-commit also fires for the cream paper area
            // INSIDE this bottom inset — specifically, the 44pt leading
            // margin to the left of the to-do patch, the 18pt trailing
            // margin to the right, and the gap between EventAddRow and
            // TodoBlock. Buttons (EventAddRow, TodoRow, idle TodoAddRow)
            // and the inline TextField (composing TodoAddRow) all
            // consume their own taps before reaching this gesture, so it
            // only catches dead-space taps.
            .contentShape(Rectangle())
            .onTapGesture {
                commitPendingTaskIfAny()
            }
        }
    }

    @ViewBuilder
    private var stickyNoteOverlay: some View {
        if let insights = viewModel?.insights, !insights.isEmpty,
           (try? settingsStore.current())?.aiStickyNotesEnabled != false
        {
            AIStickyStack(
                insights: insights,
                onTap: { insight in handleStickyTap(insight) },
                onDismiss: { insight in
                    Task { await viewModel?.dismissInsight(insight) }
                },
                onRefresh: {
                    Task { await viewModel?.refreshInsights() }
                },
                onNavigate: { _ in })
                .padding(.top, 96)
                .padding(.trailing, 16)
        }
    }

    /// Dispatch the sticky's `actionURL` to the right surface based on
    /// `kind`. Internal schemes (`weeklyplanner://event/<uuid>`,
    /// `weeklyplanner://inbox/<dayKey>`) go through `DeepLinkRouter`;
    /// external schemes (`http://maps.apple.com/...`, `weather://`) open
    /// via `UIApplication.shared.open(_:)`.
    private func handleStickyTap(_ insight: AIInsight) {
        guard let raw = insight.actionURL, let url = URL(string: raw) else { return }
        if raw.hasPrefix("weeklyplanner://event/") {
            let uuidString = raw.replacingOccurrences(of: "weeklyplanner://event/", with: "")
            if let id = UUID(uuidString: uuidString) {
                deepLinkRouter.request(.event(id))
            }
        } else if raw.hasPrefix("weeklyplanner://inbox/") {
            let dayKey = raw.replacingOccurrences(of: "weeklyplanner://inbox/", with: "")
            deepLinkRouter.request(.inbox(dayKey: dayKey))
        } else {
            UIApplication.shared.open(url)
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
                    EventEntryList(events: viewModel.events,
                                   onTap: { event in
                                       commitPendingTaskIfAny()
                                       openEventOccurrenceStart = event.start
                                       openEventID = event.id
                                   },
                                   onEdit: { event in
                                       commitPendingTaskIfAny()
                                       editingEventID = event.id
                                   },
                                   onDelete: { event in
                                       commitPendingTaskIfAny()
                                       Task { await viewModel.deleteEvent(id: event.id) }
                                   })
                }

                if hasInbox {
                    InboxBlock(suggestions: viewModel.inbox,
                               onAccept: { id in
                                   commitPendingTaskIfAny()
                                   Task { await viewModel.accept(suggestionID: id) }
                               },
                               onDismiss: { id in
                                   commitPendingTaskIfAny()
                                   Task { await viewModel.dismiss(suggestionID: id) }
                               })
                }

                // EventAddRow is pinned at the bottom alongside TodoBlock
                // (see `bottomAffordances`) — not inline here — so it
                // stays visible when the events list overflows.
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
