import Foundation
import TokenmonDomain
import TokenmonProviders

public struct OpenCodeBackfillResult: Sendable {
    public let backfillRunID: Int64
    public let sessionID: String?
    public let status: String
    public let samplesExamined: Int64
    public let samplesCreated: Int64
    public let duplicatesSkipped: Int64
    public let errorsCount: Int64
    public let summaryJSON: String
}

private struct OpenCodeBackfillSummary: Encodable {
    let provider: String
    let mode: String
    let dbPath: String
    let samplesExamined: Int64
    let samplesCreated: Int64
    let duplicatesSkipped: Int64
    let errorsCount: Int64

    enum CodingKeys: String, CodingKey {
        case provider
        case mode
        case dbPath = "db_path"
        case samplesExamined = "samples_examined"
        case samplesCreated = "samples_created"
        case duplicatesSkipped = "duplicates_skipped"
        case errorsCount = "errors_count"
    }
}

private struct OpenCodeBackfillFailureSummary: Encodable {
    let provider: String
    let mode: String
    let dbPath: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case provider
        case mode
        case dbPath = "db_path"
        case reason
    }
}

public enum OpenCodeBackfillService {
    public static func run(
        databasePath: String,
        dbPath: String
    ) throws -> OpenCodeBackfillResult {
        let database = try TokenmonDatabaseManager(path: databasePath).open()
        let key = sourceKey(dbPath: dbPath)
        let checkpoint = try IngestSourceCheckpointStore.loadOrCreate(
            database: database,
            sourceKey: key,
            sourceKind: "recovery_scan",
            path: dbPath
        )
        let sinceValue = checkpoint.lastEventFingerprint

        do {
            let events = try OpenCodeSQLiteAdapter.providerEvents(
                from: dbPath,
                since: sinceValue
            )

            if events.isEmpty {
                try upsertBackfillHealth(
                    database: database,
                    healthState: "experimental",
                    message: "OpenCode SQLite backfill found no new events",
                    lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                    lastErrorAt: nil,
                    lastErrorSummary: nil
                )
                return OpenCodeBackfillResult(
                    backfillRunID: 0,
                    sessionID: nil,
                    status: "noop",
                    samplesExamined: 0,
                    samplesCreated: 0,
                    duplicatesSkipped: 0,
                    errorsCount: 0,
                    summaryJSON: "{\"provider\":\"opencode\",\"mode\":\"opencode_sqlite_backfill\",\"status\":\"noop\",\"reason\":\"no_new_events\"}"
                )
            }

            let resolvedSessionID = events.first?.providerSessionID

            let ingestService = UsageSampleIngestionService(databasePath: databasePath)
            let ingestResult = try ingestService.ingestProviderEvents(
                database: database,
                events: events,
                sourceKey: key,
                sourcePath: dbPath,
                sourceKind: "recovery_scan",
                manageSourceCheckpoint: false
            )

            if let lastEvent = events.last {
                try advanceCheckpoint(
                    database: database,
                    checkpoint: checkpoint,
                    dbPath: dbPath,
                    lastEvent: lastEvent
                )
            }

            let samplesExamined = Int64(events.count)
            let samplesCreated = Int64(ingestResult.usageSamplesCreated)
            let duplicatesSkipped = Int64(ingestResult.duplicateEvents)
            let errorsCount = Int64(ingestResult.rejectedEvents)

            if samplesCreated == 0, duplicatesSkipped > 0, errorsCount == 0 {
                try upsertBackfillHealth(
                    database: database,
                    healthState: "experimental",
                    message: "OpenCode SQLite backfill advanced checkpoint; all appended samples were duplicates",
                    lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                    lastErrorAt: nil,
                    lastErrorSummary: nil
                )
                return OpenCodeBackfillResult(
                    backfillRunID: 0,
                    sessionID: resolvedSessionID,
                    status: "noop",
                    samplesExamined: samplesExamined,
                    samplesCreated: 0,
                    duplicatesSkipped: duplicatesSkipped,
                    errorsCount: 0,
                    summaryJSON: "{\"provider\":\"opencode\",\"mode\":\"opencode_sqlite_backfill\",\"status\":\"noop\",\"reason\":\"duplicates_only\",\"duplicates_skipped\":\(duplicatesSkipped)}"
                )
            }

            let backfillRunID = try BackfillRunStore.startBackfillRun(
                database: database,
                provider: .opencode,
                providerSessionID: resolvedSessionID,
                mode: "opencode_sqlite_backfill"
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.backfillStarted(
                    runID: backfillRunID,
                    provider: .opencode,
                    sessionID: resolvedSessionID,
                    reason: "Recover OpenCode token usage samples from SQLite database"
                )
            )

            let summaryJSON = try encodeSummary(
                OpenCodeBackfillSummary(
                    provider: ProviderCode.opencode.rawValue,
                    mode: "opencode_sqlite_backfill",
                    dbPath: dbPath,
                    samplesExamined: samplesExamined,
                    samplesCreated: samplesCreated,
                    duplicatesSkipped: duplicatesSkipped,
                    errorsCount: errorsCount
                )
            )

            _ = try BackfillRunStore.completeBackfillRun(
                database: database,
                backfillRunID: backfillRunID,
                provider: .opencode,
                mode: "opencode_sqlite_backfill",
                status: "completed",
                samplesExamined: samplesExamined,
                samplesCreated: samplesCreated,
                duplicatesSkipped: duplicatesSkipped,
                errorsCount: errorsCount,
                summaryJSON: summaryJSON
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.backfillCompleted(
                    runID: backfillRunID,
                    provider: .opencode,
                    sessionID: resolvedSessionID,
                    samplesExamined: samplesExamined,
                    samplesCreated: samplesCreated,
                    duplicatesSkipped: duplicatesSkipped,
                    errorsCount: errorsCount
                )
            )

            try upsertBackfillHealth(
                database: database,
                healthState: "experimental",
                message: "OpenCode SQLite backfill completed successfully",
                lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                lastErrorAt: nil,
                lastErrorSummary: nil
            )

            return OpenCodeBackfillResult(
                backfillRunID: backfillRunID,
                sessionID: resolvedSessionID,
                status: "completed",
                samplesExamined: samplesExamined,
                samplesCreated: samplesCreated,
                duplicatesSkipped: duplicatesSkipped,
                errorsCount: errorsCount,
                summaryJSON: summaryJSON
            )
        } catch {
            let summaryJSON = try encodeSummary(
                OpenCodeBackfillFailureSummary(
                    provider: ProviderCode.opencode.rawValue,
                    mode: "opencode_sqlite_backfill",
                    dbPath: dbPath,
                    reason: error.localizedDescription
                )
            )

            let backfillRunID = try BackfillRunStore.startBackfillRun(
                database: database,
                provider: .opencode,
                providerSessionID: nil,
                mode: "opencode_sqlite_backfill"
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.backfillStarted(
                    runID: backfillRunID,
                    provider: .opencode,
                    sessionID: nil,
                    reason: "Recover OpenCode token usage samples from SQLite database"
                )
            )

            try upsertBackfillHealth(
                database: database,
                healthState: "degraded",
                message: "OpenCode SQLite backfill failed",
                lastSuccessAt: nil,
                lastErrorAt: ISO8601DateFormatter().string(from: Date()),
                lastErrorSummary: error.localizedDescription
            )

            _ = try BackfillRunStore.completeBackfillRun(
                database: database,
                backfillRunID: backfillRunID,
                provider: .opencode,
                mode: "opencode_sqlite_backfill",
                status: "failed",
                samplesExamined: 0,
                samplesCreated: 0,
                duplicatesSkipped: 0,
                errorsCount: 1,
                summaryJSON: summaryJSON
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.backfillCompleted(
                    runID: backfillRunID,
                    provider: .opencode,
                    sessionID: nil,
                    samplesExamined: 0,
                    samplesCreated: 0,
                    duplicatesSkipped: 0,
                    errorsCount: 1
                )
            )

            throw error
        }
    }

    private static func sourceKey(dbPath: String) -> String {
        "opencode:sqlite:\(dbPath)"
    }

    private static func advanceCheckpoint(
        database: SQLiteDatabase,
        checkpoint: IngestSourceCheckpoint,
        dbPath: String,
        lastEvent: ProviderUsageSampleEvent
    ) throws {
        try IngestSourceCheckpointStore.advance(
            database: database,
            sourceID: checkpoint.ingestSourceID,
            path: dbPath,
            offset: 0,
            lineNumber: 0,
            fingerprint: lastEvent.rawReference.offset
        )
    }

    private static func upsertBackfillHealth(
        database: SQLiteDatabase,
        healthState: String,
        message: String,
        lastSuccessAt: String?,
        lastErrorAt: String?,
        lastErrorSummary: String?
    ) throws {
        let updatedAt = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO provider_health (
                provider_code,
                source_mode,
                health_state,
                message,
                last_success_at,
                last_error_at,
                last_error_code,
                last_error_summary,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?)
            ON CONFLICT(provider_code, source_mode) DO UPDATE SET
                health_state = excluded.health_state,
                message = excluded.message,
                last_success_at = COALESCE(excluded.last_success_at, provider_health.last_success_at),
                last_error_at = excluded.last_error_at,
                last_error_code = NULL,
                last_error_summary = excluded.last_error_summary,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(ProviderCode.opencode.rawValue),
                .text("opencode_sqlite_backfill"),
                .text(healthState),
                .text(message),
                lastSuccessAt.map(SQLiteValue.text) ?? .null,
                lastErrorAt.map(SQLiteValue.text) ?? .null,
                lastErrorSummary.map(SQLiteValue.text) ?? .null,
                .text(updatedAt),
            ]
        )
    }

    private static func encodeSummary<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
