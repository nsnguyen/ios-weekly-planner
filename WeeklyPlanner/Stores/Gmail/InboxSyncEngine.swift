import Foundation
import os

private let syncLog = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "InboxSync")

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
            syncLog.info("SYNC start (delta) cursor=\(cursor, privacy: .public)")
            do {
                let history = try await client.history(startHistoryId: cursor)
                stubs = (history.history ?? []).flatMap { record in
                    (record.messagesAdded ?? []).map(\.message)
                }
            } catch GmailClientError.historyExpired {
                syncLog.info("history expired -> falling back to full re-sync")
                stubs = try await client.listMessages(
                    query: GmailQueryBuilder.defaultQuery(),
                    maxResults: 50
                )
            }
        } else {
            syncLog.info("SYNC start (full) cursor=nil")
            stubs = try await client.listMessages(
                query: GmailQueryBuilder.defaultQuery(),
                maxResults: 50
            )
        }
        syncLog.info("SYNC fetched \(stubs.count, privacy: .public) message stub(s)")

        // 2. Fetch + classify + extract + upsert each. Each iteration is its
        // own do/catch so a single bad message (404, decode failure, model
        // hiccup) doesn't kill the whole sync — the failure is logged and
        // the loop continues.
        var added = 0
        var skipped = 0
        for (index, stub) in stubs.enumerated() {
            continuation?.yield(SyncProgress(stage: .classifying, processed: index, total: stubs.count))
            syncLog.info("[\(stub.id, privacy: .public)] BEGIN iteration \(index + 1, privacy: .public)/\(stubs.count, privacy: .public)")

            do {
                if try await isAlreadyHandled(messageID: stub.id) {
                    syncLog.info("[\(stub.id, privacy: .public)] SKIP already handled")
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
                    syncLog.info("[\(stub.id, privacy: .public)] SKIP classifier rejected subject=\(subject, privacy: .public)")
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
                syncLog.info("""
                    [\(stub.id, privacy: .public)] EXTRACTED \
                    isEvent=\(extracted.isEvent, privacy: .public) \
                    confidence=\(extracted.confidence, privacy: .public) \
                    title=\(extracted.title ?? "nil", privacy: .public) \
                    startISO=\(extracted.startISO ?? "nil", privacy: .public) \
                    endISO=\(extracted.endISO ?? "nil", privacy: .public) \
                    location=\(extracted.location ?? "nil", privacy: .public) \
                    subject=\(subject, privacy: .public)
                    """)
                guard extracted.isEvent, extracted.confidence >= 0.55 else {
                    syncLog.info("[\(stub.id, privacy: .public)] SKIP isEvent=\(extracted.isEvent, privacy: .public) confidence=\(extracted.confidence, privacy: .public)")
                    skipped += 1
                    continue
                }

                guard let suggestion = InboxSuggestion.fromExtractedEvent(extracted, message: message) else {
                    syncLog.info("[\(stub.id, privacy: .public)] SKIP fromExtractedEvent returned nil (date parse failure?)")
                    skipped += 1
                    continue
                }
                guard suggestion.proposedStart > now else {
                    syncLog.info("[\(stub.id, privacy: .public)] SKIP past-dated proposedStart=\(suggestion.proposedStart, privacy: .public) now=\(now, privacy: .public)")
                    skipped += 1
                    continue
                }
                try await inboxStore.upsert(suggestion)
                syncLog.info("[\(stub.id, privacy: .public)] UPSERT proposedStart=\(suggestion.proposedStart, privacy: .public) title=\(suggestion.title, privacy: .public)")
                added += 1
            } catch {
                syncLog.error("[\(stub.id, privacy: .public)] THROW \(String(describing: error), privacy: .public)")
                skipped += 1
                continue
            }
        }

        // 3. Persist the new cursor.
        let profile = try await client.profile()
        deltaSync.saveCursor(profile.historyId)

        continuation?.yield(SyncProgress(stage: .done, processed: stubs.count, total: stubs.count))
        syncLog.info("SYNC done added=\(added, privacy: .public) skipped=\(skipped, privacy: .public) newCursor=\(profile.historyId, privacy: .public)")
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
