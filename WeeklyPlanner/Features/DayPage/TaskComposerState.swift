import Foundation
import Observation

/// Editable draft for a new `TaskItem`. Held by `DayPageViewModel` and
/// bound to the inline `+ add a task` row in `TodoBlock`. Two-way bound
/// via `@Bindable` so `TextField` two-way bindings work.
///
/// The composer exposes only the fields the inline row + mini popover
/// expose to the user: title, priority, due. `category` is supplied by
/// the caller at `build(category:)` time (defaults to `.personal` from
/// the view-model layer).
@MainActor
@Observable
final class TaskComposerState {
    var title: String = ""
    var isComposing: Bool = false
    var priority: Priority = .med
    var due: Date

    /// Monotonic counter incremented every time external code calls
    /// `requestBlur()`. `TodoAddRow` watches this via `.onChange` to
    /// know when to relinquish focus on its inline TextField — the
    /// SwiftUI-friendly way to plumb "force-blur" through `@Observable`
    /// without exposing a `FocusState.Binding` up four layers.
    private(set) var pendingBlurToken: Int = 0

    init(forDay date: Date) {
        self.due = date
    }

    /// Ask the inline-add row's TextField to relinquish focus. Called by
    /// `DayPageContent` when a tap lands anywhere on the page outside the
    /// to-do block while the composer is active — the Notes-style
    /// "tap outside to lock in" affordance. The blur then trips the
    /// existing commit-or-exit handler in `TodoAddRow`.
    func requestBlur() {
        pendingBlurToken &+= 1
    }

    var canCommit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Build a fresh `TaskItem` from the current draft. Caller supplies
    /// the `category` (typically `.personal` until the UI exposes a
    /// picker). Trims whitespace from the title; `done` always starts
    /// false; reminders are nil — the popover doesn't manage reminders
    /// in v1.
    func build(category: Category = .personal) -> TaskItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return TaskItem(title: trimmed,
                         due: due,
                         done: false,
                         priority: priority,
                         category: category)
    }

    /// Clear the title; KEEP `isComposing == true` so the user can chain
    /// add-task entries by tapping Return repeatedly.
    func reset() {
        title = ""
    }

    /// Clear everything and exit composing. Used when the user blurs the
    /// field with an empty title, taps Cancel, or the popover dismisses.
    func exit() {
        title = ""
        priority = .med
        isComposing = false
    }

    /// Update the anchor day. Called when the composer is mounted on a
    /// new Day page (e.g., user flipped to a different day with the
    /// composer open).
    func setDay(_ date: Date) {
        due = date
    }
}
