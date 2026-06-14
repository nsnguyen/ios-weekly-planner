import Foundation
import os

private let syncLog = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "GCalSync")

/// Orchestrates Google Calendar import: full sync when no cursor, incremental
/// when one is stored, automatic fallback to full on 410 Gone.
///
/// Single-flight via the @MainActor-isolated `isRunning` flag — a concurrent
/// call while a sync is in progress returns immediately.
@MainActor
final class GCalSyncEngine {
    private let client: any GoogleCalendarClientProtocol
    private let eventStore: any EventStoring
    private let deltaSync: GCalDeltaSync
    private let clock: () -> Date

    private var isRunning = false

    init(
        client: any GoogleCalendarClientProtocol,
        eventStore: any EventStoring,
        deltaSync: GCalDeltaSync,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.client = client
        self.eventStore = eventStore
        self.deltaSync = deltaSync
        self.clock = clock
    }

    // MARK: - Sync

    func sync() async {
        guard !isRunning else {
            syncLog.info("GCalSync skipped — already running")
            return
        }
        isRunning = true; defer { isRunning = false }

        // Mutable locals so the 410-restart path can reset without recursion.
        var token: String? = deltaSync.currentToken()
        var full = (token == nil)
        var pageToken: String?

        syncLog.info("GCalSync start token=\(token ?? "nil", privacy: .public) full=\(full, privacy: .public)")

        // Outer loop: normally runs once; loops again only after a 410 reset.
        repeat {
            let timeMin: Date? = full ? clock().addingTimeInterval(-60 * 24 * 3600) : nil
            let timeMax: Date? = full ? clock().addingTimeInterval(120 * 24 * 3600) : nil

            // Inner page loop.
            var continueFromTop = false
            repeat {
                let page: GCalEventsListResponse
                do {
                    page = try await client.listEvents(
                        syncToken: token,
                        timeMin: timeMin,
                        timeMax: timeMax,
                        pageToken: pageToken
                    )
                } catch GoogleCalendarClientError.syncTokenExpired {
                    syncLog.info("GCalSync 410 syncTokenExpired — falling back to full re-sync")
                    // Reset cursor and switch to full mode; restart the outer loop.
                    deltaSync.save(nil)
                    token = nil
                    full = true
                    pageToken = nil
                    continueFromTop = true
                    break
                } catch {
                    syncLog.error("GCalSync listEvents error: \(String(describing: error), privacy: .public)")
                    return
                }

                // Process items — per-item isolation so one bad item can't kill the batch.
                for item in page.items {
                    do { try await apply(item) } catch {
                        syncLog.error("GCalSync item \(item.id, privacy: .public) error: \(String(describing: error), privacy: .public)")
                        continue
                    }
                }

                // Persist sync token as soon as the server hands it back.
                if let nextSyncToken = page.nextSyncToken {
                    deltaSync.save(nextSyncToken)
                    syncLog.info("GCalSync stored nextSyncToken=\(nextSyncToken, privacy: .public)")
                }

                pageToken = page.nextPageToken
            } while pageToken != nil

            if continueFromTop { continue }
            break
        } while true

        syncLog.info("GCalSync done token=\(self.deltaSync.currentToken() ?? "nil", privacy: .public)")
    }

    // MARK: - Per-item apply

    private func apply(_ item: GCalEvent) async throws {
        if item.status == "cancelled" {
            let id = GCalMapper.deterministicID(for: item.id)
            try await eventStore.delete(id: id)
            syncLog.info("GCalSync deleted \(item.id, privacy: .public)")
        } else if let event = GCalMapper.event(from: item) {
            try await eventStore.upsert(event)
            syncLog.info("GCalSync upserted \(item.id, privacy: .public) title=\(event.title, privacy: .public)")
        }
        // else: mapper returned nil for non-cancelled item (missing dates) → skip
    }

    // MARK: - Purge

    /// Removes all Google Calendar-sourced events from the store and clears
    /// the sync cursor. Call this when the user disconnects their Google account.
    func purge() async {
        do {
            let gcalEvents = try await eventStore.events(source: .googleCalendar)
            for event in gcalEvents {
                try? await eventStore.delete(id: event.id)
            }
        } catch {
            syncLog.error("GCalSync purge fetch error: \(String(describing: error), privacy: .public)")
        }
        deltaSync.save(nil)
        syncLog.info("GCalSync purge complete")
    }
}
