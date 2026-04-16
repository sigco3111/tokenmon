import Foundation
import TokenmonDomain
import TokenmonProviders

public struct ClaudeTranscriptBackfillResult: Sendable {
    public let backfillRunID: Int64
    public let sessionID: String?
    public let status: String
    public let samplesExamined: Int64
    public let samplesCreated: Int64
    public let duplicatesSkipped: Int64
    public let errorsCount: Int64
    public let collapsedDuplicateMessages: Int
    public let summaryJSON: String
}

private struct ClaudeTranscriptBackfillSummary: Encodable {
    let provider: String
    let mode: String
    let sessionID: String?
    let transcriptPath: String
    let samplesExamined: Int64
    let samplesCreated: Int64
    let duplicatesSkipped: Int64
    let errorsCount: Int64
    let collapsedDuplicateMessages: Int

    enum CodingKeys: String, CodingKey {
        case provider
        case mode
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case samplesExamined = "samples_examined"
        case samplesCreated = "samples_created"
        case duplicatesSkipped = "duplicates_skipped"
        case errorsCount = "errors_count"
        case collapsedDuplicateMessages = "collapsed_duplicate_messages"
    }
}

private struct ClaudeTranscriptBackfillFailureSummary: Encodable {
    let provider: String
    let mode: String
    let sessionID: String?
    let transcriptPath: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case provider
        case mode
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case reason
    }
}

public enum ClaudeTranscriptBackfillService {
    public static func run(
        databasePath: String,
        providerSessionID: String?,
        transcriptPath: String
    ) throws -> ClaudeTranscriptBackfillResult {
        let database = try TokenmonDatabaseManager(path: databasePath).open()
        let backfillRunID = try BackfillRunStore.startBackfillRun(
            database: database,
            provider: .claude,
            providerSessionID: providerSessionID,
            mode: "transcript_backfill"
        )

        try DomainEventStore.persist(
            database: database,
            envelope: TokenmonDomainEventRegistry.backfillStarted(
                runID: backfillRunID,
                provider: .claude,
                sessionID: providerSessionID,
                reason: "Recover usage-bearing Claude assistant steps from transcript"
            )
        )

        do {
            let importResult = try ClaudeTranscriptBackfillAdapter.importTranscript(
                from: transcriptPath,
                config: ClaudeTranscriptBackfillAdapterConfig(sessionIDFallback: providerSessionID)
            )
            let ingestService = UsageSampleIngestionService(databasePath: databasePath)
            let ingestResult = try ingestService.ingestProviderEvents(
                database: database,
                events: importResult.events,
                sourceKey: sourceKey(
                    sessionID: importResult.sessionID,
                    transcriptPath: transcriptPath
                ),
                sourcePath: transcriptPath,
                sourceKind: "recovery_scan"
            )

            let samplesExamined = Int64(importResult.events.count)
            let samplesCreated = Int64(ingestResult.usageSamplesCreated)
            let duplicatesSkipped = Int64(ingestResult.duplicateEvents)
            let errorsCount = Int64(ingestResult.rejectedEvents)
            let summaryJSON = try encodeSummary(
                ClaudeTranscriptBackfillSummary(
                    provider: ProviderCode.claude.rawValue,
                    mode: "transcript_backfill",
                    sessionID: importResult.sessionID,
                    transcriptPath: transcriptPath,
                    samplesExamined: samplesExamined,
                    samplesCreated: samplesCreated,
                    duplicatesSkipped: duplicatesSkipped,
                    errorsCount: errorsCount,
                    collapsedDuplicateMessages: importResult.collapsedDuplicateMessages
                )
            )

            _ = try BackfillRunStore.completeBackfillRun(
                database: database,
                backfillRunID: backfillRunID,
                provider: .claude,
                mode: "transcript_backfill",
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
                    provider: .claude,
                    sessionID: importResult.sessionID,
                    samplesExamined: samplesExamined,
                    samplesCreated: samplesCreated,
                    duplicatesSkipped: duplicatesSkipped,
                    errorsCount: errorsCount
                )
            )

            try upsertBackfillHealth(
                database: database,
                healthState: "connected",
                message: "Claude transcript backfill completed",
                lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                lastErrorAt: nil,
                lastErrorSummary: nil
            )

            return ClaudeTranscriptBackfillResult(
                backfillRunID: backfillRunID,
                sessionID: importResult.sessionID,
                status: "completed",
                samplesExamined: samplesExamined,
                samplesCreated: samplesCreated,
                duplicatesSkipped: duplicatesSkipped,
                errorsCount: errorsCount,
                collapsedDuplicateMessages: importResult.collapsedDuplicateMessages,
                summaryJSON: summaryJSON
            )
        } catch {
            let summaryJSON = try encodeSummary(
                ClaudeTranscriptBackfillFailureSummary(
                    provider: ProviderCode.claude.rawValue,
                    mode: "transcript_backfill",
                    sessionID: providerSessionID,
                    transcriptPath: transcriptPath,
                    reason: error.localizedDescription
                )
            )

            _ = try BackfillRunStore.completeBackfillRun(
                database: database,
                backfillRunID: backfillRunID,
                provider: .claude,
                mode: "transcript_backfill",
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
                    provider: .claude,
                    sessionID: providerSessionID,
                    samplesExamined: 0,
                    samplesCreated: 0,
                    duplicatesSkipped: 0,
                    errorsCount: 1
                )
            )

            try upsertBackfillHealth(
                database: database,
                healthState: "degraded",
                message: "Claude transcript backfill failed",
                lastSuccessAt: nil,
                lastErrorAt: ISO8601DateFormatter().string(from: Date()),
                lastErrorSummary: error.localizedDescription
            )

            throw error
        }
    }

    private static func sourceKey(sessionID: String, transcriptPath: String) -> String {
        "recovery:claude:\(sessionID):\(URL(fileURLWithPath: transcriptPath).path)"
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
                .text(ProviderCode.claude.rawValue),
                .text("claude_transcript_backfill"),
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
