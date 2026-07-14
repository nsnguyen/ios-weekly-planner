import Foundation

enum GCalWriteBackContext {
    /// When true, `GoogleCalendarWriteBackEventStore` must not call Google.
    /// Set during import apply and disconnect purge.
    @TaskLocal static var suppressWriteBack: Bool = false
}
