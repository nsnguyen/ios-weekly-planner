import Foundation
import SwiftData

@MainActor
protocol AnnotationStoring: AnyObject {
    /// Annotations for one day cell, oldest-first (stable z-order).
    func annotations(dayKey: String) async throws -> [Annotation]
    func upsert(_ annotation: Annotation) async throws
    func delete(id: UUID) async throws
}

@MainActor
final class SwiftDataAnnotationStore: AnnotationStoring {
    private let context: ModelContext
    private let changeSubject = NotificationCenter.default

    init(context: ModelContext) {
        self.context = context
    }

    func annotations(dayKey: String) async throws -> [Annotation] {
        try context.fetch(FetchDescriptor<Annotation>(
            predicate: #Predicate<Annotation> { $0.dayKey == dayKey },
            sortBy: [SortDescriptor(\Annotation.createdAt, order: .forward)]))
    }

    func upsert(_ annotation: Annotation) async throws {
        let id = annotation.id
        let existing = try context.fetch(
            FetchDescriptor<Annotation>(predicate: #Predicate<Annotation> { $0.id == id })).first

        if let existing {
            existing.dayKey = annotation.dayKey
            existing.text = annotation.text
            existing.colorTokenRaw = annotation.colorTokenRaw
            existing.isBold = annotation.isBold
            existing.unitX = annotation.unitX
            existing.unitY = annotation.unitY
            existing.updatedAt = .init()
        } else {
            context.insert(annotation)
        }
        try context.save()
        changeSubject.post(name: .annotationStoreDidChange, object: nil)
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<Annotation>(predicate: #Predicate<Annotation> { $0.id == id })
        if let annotation = try context.fetch(descriptor).first {
            context.delete(annotation)
            try context.save()
            changeSubject.post(name: .annotationStoreDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let annotationStoreDidChange = Notification.Name("WeeklyPlanner.AnnotationStore.didChange")
}

/// Inert default for previews and unwired subtrees.
@MainActor
final class StubAnnotationStore: AnnotationStoring {
    nonisolated init() {}

    func annotations(dayKey _: String) async throws -> [Annotation] { [] }
    func upsert(_: Annotation) async throws {}
    func delete(id _: UUID) async throws {}
}
