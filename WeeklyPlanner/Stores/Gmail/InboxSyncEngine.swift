import Foundation

struct SyncProgress: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        case fetching
        case classifying
        case extracting
        case done
    }
    let stage: Stage
    let processed: Int
    let total: Int
}

struct SyncResult: Equatable, Sendable {
    let added: Int
    let updated: Int
    let skipped: Int
}

/// Orchestrates a single Gmail sync: fetch new messages (delta if cursor
/// present, full otherwise), classify cheaply, extract with Foundation
/// Models (or stub), upsert `InboxSuggestion` rows, persist the new
/// cursor. Single-flight via the `@MainActor`-isolated state — a second
/// concurrent call awaits the first.
///
/// Progress events are surfaced via `progressStream` so the AppShell
/// top-bar spinner can render while the engine is active.
@MainActor
final class InboxSyncEngine {
    private let client: any GmailClientProtocol
    private let extractor: any EventExtractor
    private let inboxStore: any InboxStoring
    private let deltaSync: GmailDeltaSync

    private var isRunning = false
    private var continuation: AsyncStream<SyncProgress>.Continuation?

    /// Public progress stream. UI subscribes via `for await progress in engine.progressStream`.
    let progressStream: AsyncStream<SyncProgress>

    init(
        client: any GmailClientProtocol,
        extractor: any EventExtractor,
        inboxStore: any InboxStoring,
        deltaSync: GmailDeltaSync
    ) {
        self.client = client
        self.extractor = extractor
        self.inboxStore = inboxStore
        self.deltaSync = deltaSync
        var emitter: AsyncStream<SyncProgress>.Continuation!
        progressStream = AsyncStream { emitter = $0 }
        continuation = emitter
    }

    func sync(now: Date) async throws -> SyncResult {
        while isRunning {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        isRunning = true
        defer { isRunning = false }

        continuation?.yield(SyncProgress(stage: .fetching, processed: 0, total: 0))

        // 1. Decide delta vs full sync.
        let stubs: [GmailMessageStub]
        if let cursor = deltaSync.currentCursor() {
            do {
                let history = try await client.history(startHistoryId: cursor)
                stubs = (history.history ?? []).flatMap { record in
                    (record.messagesAdded ?? []).map(\.message)
                }
            } catch GmailClientError.historyExpired {
                stubs = try await client.listMessages(
                    query: GmailQueryBuilder.defaultQuery(),
                    maxResults: 50
                )
            }
        } else {
            stubs = try await client.listMessages(
                query: GmailQueryBuilder.defaultQuery(),
                maxResults: 50
            )
        }

        // 2. Fetch + classify + extract + upsert each.
        var added = 0
        var skipped = 0
        for (index, stub) in stubs.enumerated() {
            continuation?.yield(SyncProgress(stage: .classifying, processed: index, total: stubs.count))

            if try await isAlreadyHandled(messageID: stub.id) {
                skipped += 1
                continue
            }

            let message = try await client.fetchMessage(id: stub.id, format: .full)
            let subject = message.header("Subject") ?? ""
            let fromHeader = message.header("From") ?? ""
            let verdict = MessageClassifier.classify(
                subject: subject,
                fromName: fromHeader,
                fromEmail: extractEmail(from: fromHeader)
            )
            guard verdict.passes else {
                skipped += 1
                continue
            }

            continuation?.yield(SyncProgress(stage: .extracting, processed: index, total: stubs.count))
            let extracted = try await extractor.extract(
                subject: subject,
                snippet: message.snippet ?? "",
                fromName: fromHeader,
                fromEmail: extractEmail(from: fromHeader),
                body: message.plainTextBody()
            )
            guard extracted.isEvent, extracted.confidence >= 0.55 else {
                skipped += 1
                continue
            }

            guard let suggestion = InboxSuggestion.fromExtractedEvent(extracted, message: message) else {
                skipped += 1
                continue
            }
            guard suggestion.proposedStart > now else {
                skipped += 1
                continue
            }
            try await inboxStore.upsert(suggestion)
            added += 1
        }

        // 3. Persist the new cursor.
        let profile = try await client.profile()
        deltaSync.saveCursor(profile.historyId)

        continuation?.yield(SyncProgress(stage: .done, processed: stubs.count, total: stubs.count))
        return SyncResult(added: added, updated: 0, skipped: skipped)
    }

    private func isAlreadyHandled(messageID: String) async throws -> Bool {
        guard let existing = try await inboxStore.anyStatus(forMessageID: messageID) else { return false }
        return existing.status != .pending // already accepted or dismissed
    }

    private func extractEmail(from header: String) -> String {
        guard let open = header.firstIndex(of: "<"),
              let close = header.firstIndex(of: ">"),
              open < close
        else { return header.trimmingCharacters(in: .whitespaces) }
        return String(header[header.index(after: open)..<close])
    }
}
