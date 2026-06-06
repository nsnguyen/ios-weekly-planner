import Foundation
import Observation
import SwiftData

/// Drives the Paper Day page for a single `(weekOffset, dayIdx)` cell.
///
/// Owns the per-day slice of events, pending inbox suggestions, and to-dos,
/// plus the derived `isToday` flag used by the header chip. The view
/// triggers `refresh()` from `.task` on appear and after every mutation;
/// real-time AsyncStream observation is deferred until SwiftData `@Model`
/// types are `Sendable` across actor hops (see `EventStore` notes).
///
/// All store calls are `@MainActor`-isolated, so this class is too.
@MainActor
@Observable
final class DayPageViewModel {
    /// Week the page belongs to, relative to "today's week" (0 = current).
    let weekOffset: Int

    /// Monday-based day index within the week (0 = Mon … 6 = Sun).
    let dayIdx: Int

    /// `"<weekOffset>:<dayIdx>"` — shared dayKey scheme.
    var dayKey: String { Annotation.key(weekOffset: weekOffset, dayIdx: dayIdx) }

    /// Events scheduled for this day, sorted ascending by `start`.
    var events: [Event] = []

    /// Pending inbox suggestions whose `proposedStart` lands on this day.
    var inbox: [InboxSuggestion] = []

    /// To-dos whose `due` date lands on this day, sorted high-priority-first
    /// then alphabetical by title for stability.
    var tasks: [TaskItem] = []

    /// Cascade of AI sticky-note insights for this day, sorted by
    /// `priority` ascending (lower = top of the stack). Populated by
    /// `refresh()` from SwiftData after the `StickyOrchestrator` runs.
    /// Phase 24 — replaces the single-insight read pattern.
    var insights: [AIInsight] = []

    /// Free-text annotations placed on this day, oldest-first by creation
    /// time (stable z-order). Phase 34.
    var annotations: [Annotation] = []

    /// Localized description of the most recent fetch failure, if any.
    /// Cleared when a refresh succeeds.
    var loadError: String?

    /// Inline-add composer for the to-do block. Re-anchored to this
    /// day in `refresh()` so a flipped page hands the user a fresh row
    /// pointing at the right date.
    var taskComposer: TaskComposerState

    private let eventStore: any EventStoring
    private let inboxStore: any InboxStoring
    private let taskStore: any TaskStoring
    private let annotationStore: any AnnotationStoring
    private let orchestrator: StickyOrchestrator?
    private let modelContext: ModelContext?
    /// Read fresh on each `refresh()` to gate sticky-insight *generation*
    /// on `aiStickyNotesEnabled`. `nil` in tests/previews that don't care
    /// about the toggle, where generation is left enabled.
    private let settingsStore: (any SettingsStoring)?
    private let clock: () -> Date

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - weekOffset: Week relative to "now" (0 = current week).
    ///   - dayIdx: Monday-based index within the week.
    ///   - eventStore: Store for `Event` reads.
    ///   - inboxStore: Store for `InboxSuggestion` reads/mutations.
    ///   - taskStore: Store for `TaskItem` reads/mutations.
    ///   - orchestrator: Optional `StickyOrchestrator` that runs the
    ///     5-generator cascade and persists up to 3 `AIInsight` rows
    ///     per day. `nil` in tests/previews; the app supplies a real
    ///     one in production via `\.stickyOrchestrator`. Phase 24 —
    ///     replaces the per-VM `EncouragementInsightGenerator`.
    ///   - modelContext: Optional SwiftData context the orchestrator
    ///     writes fresh `AIInsight` rows into and the VM reads the
    ///     cascade back from. Required if `orchestrator` is non-nil.
    ///   - clock: Injected "now" so tests can pin the date. Defaults to
    ///     `Date()` in production.
    init(weekOffset: Int,
         dayIdx: Int,
         eventStore: any EventStoring,
         inboxStore: any InboxStoring,
         taskStore: any TaskStoring,
         annotationStore: any AnnotationStoring = StubAnnotationStore(),
         orchestrator: StickyOrchestrator? = nil,
         modelContext: ModelContext? = nil,
         settingsStore: (any SettingsStoring)? = nil,
         clock: @escaping () -> Date = { .init() })
    {
        self.weekOffset = weekOffset
        self.dayIdx = dayIdx
        self.eventStore = eventStore
        self.inboxStore = inboxStore
        self.taskStore = taskStore
        self.annotationStore = annotationStore
        self.orchestrator = orchestrator
        self.modelContext = modelContext
        self.settingsStore = settingsStore
        self.clock = clock
        // Anchor the composer to this day-vm's date. Re-anchored in
        // refresh() so the composer always points at the focused day
        // even if the system date crosses midnight while the page is open.
        let days = WeekMath.weekDays(forOffset: weekOffset, today: clock())
        let anchor = days.indices.contains(dayIdx) ? days[dayIdx].date : clock()
        self.taskComposer = TaskComposerState(forDay: anchor)
    }

    /// `true` iff this page represents the current calendar day. Drives the
    /// header's `TodayChip` visibility.
    var isToday: Bool {
        guard weekOffset == 0 else { return false }
        let now = clock()
        let week = WeekMath.weekDays(forOffset: 0, today: now)
        guard let todayIdx = WeekMath.todayIndex(in: week, for: now) else { return false }
        return todayIdx == dayIdx
    }

    /// Triggered by pull-to-refresh on the Day page. Delegates to the
    /// shared `InboxSyncEngine`. Errors are swallowed (user-facing state
    /// is just "no new suggestions appeared").
    func refresh(via engine: InboxSyncEngine?) async {
        guard let engine else { return }
        _ = try? await engine.sync(now: Date())
        // After a successful sync, re-fetch suggestions for the current week.
        await refresh()
    }

    /// Re-fetch events, inbox suggestions, and to-dos from the stores and
    /// filter them to this day. Errors from any store are surfaced via
    /// `loadError` while previously-loaded data is left in place.
    func refresh() async {
        let calendar = WeekMath.mondayCalendar()
        let now = clock()

        do {
            let allEvents = try await eventStore.events(forWeekOffset: weekOffset, today: now)
            events = allEvents
                .filter { $0.weekdayIndex(in: calendar) == dayIdx }
                .sorted { $0.start < $1.start }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }

        do {
            let allInbox = try await inboxStore.pending(forWeekOffset: weekOffset, today: now)
            inbox = allInbox
                .filter { $0.proposedStart.mondayBasedWeekdayIndex(in: calendar) == dayIdx }
                .sorted { $0.proposedStart < $1.proposedStart }
        } catch {
            loadError = error.localizedDescription
        }

        do {
            let allTasks = try await taskStore.tasks(forWeekOffset: weekOffset, today: now)
            tasks = allTasks
                .filter { $0.due.mondayBasedWeekdayIndex(in: calendar) == dayIdx }
                .sorted { lhs, rhs in
                    if lhs.priority != rhs.priority {
                        return lhs.priority.sortWeight > rhs.priority.sortWeight
                    }
                    return lhs.title < rhs.title
                }
        } catch {
            loadError = error.localizedDescription
        }

        // Phase 34: free-text annotations for this day cell.
        annotations = (try? await annotationStore.annotations(dayKey: dayKey)) ?? []

        // Opt-in gate: AI sticky notes only *generate* when the user has
        // enabled them. Read fresh each refresh so a Settings toggle takes
        // effect on the next page refresh. A `nil` settingsStore (tests /
        // previews that don't care about the toggle) leaves generation on.
        let stickyEnabled: Bool
        if let settingsStore {
            stickyEnabled = (try? settingsStore.current())?.aiStickyNotesEnabled ?? false
        } else {
            stickyEnabled = true
        }

        if stickyEnabled, let orchestrator, let modelContext {
            let ctx = DayContext(weekOffset: weekOffset,
                                 dayIdx: dayIdx,
                                 events: events,
                                 inbox: inbox,
                                 now: now,
                                 appleIntelligenceEnabled: true)
            await orchestrator.run(for: ctx, into: modelContext)
            insights = StickyNoteGenerator.insights(forWeekOffset: weekOffset,
                                                    dayIdx: dayIdx,
                                                    in: modelContext)
        } else if !stickyEnabled {
            insights = []
        }

        // Re-anchor the composer in case the clock advanced past midnight
        // while the page was visible. The composer's day matches this
        // page's date, not "today".
        let days = WeekMath.weekDays(forOffset: weekOffset, today: now)
        if days.indices.contains(dayIdx) {
            taskComposer.setDay(days[dayIdx].date)
        }
    }

    /// Invalidate the orchestrator cache for this day and re-run. Wired to
    /// the `AIStickyNote` eyebrow "↻" button so the user can force-refresh
    /// the cascade without waiting for the TTL.
    func refreshInsights() async {
        guard let orchestrator, modelContext != nil else { return }
        orchestrator.invalidate(dayKey: AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx))
        await refresh()
    }

    /// Mark the insight as dismissed (it stays in SwiftData so we don't
    /// re-emit it next refresh) and remove it from the visible cascade.
    func dismissInsight(_ insight: AIInsight) async {
        insight.dismissed = true
        try? modelContext?.save()
        if let modelContext {
            insights = StickyNoteGenerator.insights(forWeekOffset: weekOffset,
                                                    dayIdx: dayIdx,
                                                    in: modelContext)
        }
    }

    /// Mark a suggestion as accepted and refresh the day's state. Errors are
    /// caught and surfaced via `loadError` so the UI never raises.
    func accept(suggestionID: UUID) async {
        do {
            try await inboxStore.accept(id: suggestionID)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }

    /// Mark a suggestion as dismissed and refresh. Same error policy as
    /// `accept(suggestionID:)`.
    func dismiss(suggestionID: UUID) async {
        do {
            try await inboxStore.dismiss(id: suggestionID)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }

    /// Flip the `done` flag on the task with the given id and refresh.
    /// Errors swallow into `loadError` so the row never throws into SwiftUI.
    func toggleTask(id: UUID) async {
        do {
            try await taskStore.toggle(id: id)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }

    /// Commit the composer's current draft. No-op when `canCommit` is
    /// false (empty title). On success, resets the composer's title (so
    /// the user can chain adds) but keeps `isComposing == true`.
    /// Surfaces errors via `loadError`.
    func addTask() async {
        guard taskComposer.canCommit else { return }
        let task = taskComposer.build(category: .personal)
        do {
            try await taskStore.upsert(task)
        } catch {
            loadError = error.localizedDescription
        }
        taskComposer.reset()
        await refresh()
    }

    /// Fetch the task by id, apply the mutation, persist via upsert.
    /// Used by the mini popover for priority / due-date / title edits.
    func updateTask(id: UUID, mutation: (TaskItem) -> Void) async {
        do {
            guard let task = try await taskStore.task(id: id) else { return }
            mutation(task)
            try await taskStore.upsert(task)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }

    /// Delete the task and refresh.
    func deleteTask(id: UUID) async {
        do {
            try await taskStore.delete(id: id)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }

    /// Delete the event by id. Routes through `EventStore.delete(id:)`
    /// which mirrors the removal to EventKit (Phase 04 decorator) and
    /// posts `.eventStoreDidChange` — the auto-refresh observer will
    /// pick that up, but we also `await refresh()` explicitly so the
    /// row disappears immediately without a publisher round-trip.
    /// Errors surface via `loadError`, matching every other store
    /// mutation in this VM.
    func deleteEvent(id: UUID) async {
        do {
            try await eventStore.delete(id: id)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }

    // MARK: - Annotations (Phase 34)

    @discardableResult
    func addAnnotation(atUnit point: CGPoint) async -> Annotation? {
        let clamped = Annotation.clampUnit(point)
        let annotation = Annotation(dayKey: dayKey,
                                    text: "",
                                    colorToken: .ink,
                                    isBold: false,
                                    unitX: clamped.x,
                                    unitY: clamped.y)
        do {
            try await annotationStore.upsert(annotation)
            await refreshAnnotations()
            return annotations.first(where: { $0.id == annotation.id })
        } catch {
            return nil
        }
    }

    /// Commit edited text. Empty (trimmed) text deletes the annotation —
    /// an abandoned draft must not leave an invisible row behind.
    func commitAnnotationText(id: UUID, text: String) async {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? await annotationStore.delete(id: id)
        } else {
            annotation.text = trimmed
            try? await annotationStore.upsert(annotation)
        }
        await refreshAnnotations()
    }

    func setAnnotationStyle(id: UUID, colorToken: InkColorToken? = nil, isBold: Bool? = nil) async {
        // Nothing to change — avoid a pointless upsert that would bump `updatedAt`.
        guard colorToken != nil || isBold != nil else { return }
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }
        if let colorToken { annotation.colorToken = colorToken }
        if let isBold { annotation.isBold = isBold }
        try? await annotationStore.upsert(annotation)
        await refreshAnnotations()
    }

    func moveAnnotation(id: UUID, toUnit point: CGPoint) async {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return }
        let clamped = Annotation.clampUnit(point)
        annotation.unitX = clamped.x
        annotation.unitY = clamped.y
        try? await annotationStore.upsert(annotation)
        await refreshAnnotations()
    }

    func deleteAnnotation(id: UUID) async {
        try? await annotationStore.delete(id: id)
        await refreshAnnotations()
    }

    private func refreshAnnotations() async {
        annotations = (try? await annotationStore.annotations(dayKey: dayKey)) ?? []
    }
}

private extension Date {
    /// Monday-based weekday index (0 = Mon … 6 = Sun). Mirrors
    /// `Event.weekdayIndex(in:)` for non-`Event` date values.
    func mondayBasedWeekdayIndex(in calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: self)
        return (weekday + 5) % 7
    }
}
