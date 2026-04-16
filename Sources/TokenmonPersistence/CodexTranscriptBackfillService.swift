import Foundation
import TokenmonDomain
import TokenmonProviders

public struct CodexTranscriptBackfillResult: Sendable {
    public let backfillRunID: Int64
    public let sessionID: String?
    public let status: String
    public let samplesExamined: Int64
    public let samplesCreated: Int64
    public let duplicatesSkipped: Int64
    public let errorsCount: Int64
    public let summaryJSON: String
}

private struct CodexTranscriptBackfillSummary: Encodable {
    let provider: String
    let mode: String
    let sessionID: String?
    let transcriptPath: String
    let samplesExamined: Int64
    let samplesCreated: Int64
    let duplicatesSkipped: Int64
    let errorsCount: Int64

    enum CodingKeys: String, CodingKey {
        case provider
        case mode
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case samplesExamined = "samples_examined"
        case samplesCreated = "samples_created"
        case duplicatesSkipped = "duplicates_skipped"
        case errorsCount = "errors_count"
    }
}

private struct CodexTranscriptBackfillFailureSummary: Encodable {
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

public enum CodexTranscriptBackfillService {
    public static func run(
        databasePath: String,
        providerSessionID: String?,
        transcriptPath: String
    ) throws -> CodexTranscriptBackfillResult {
        let database = try TokenmonDatabaseManager(path: databasePath).open()
        let sourceKey = sourceKey(transcriptPath: transcriptPath)
        var checkpoint = try IngestSourceCheckpointStore.loadOrCreate(
            database: database,
            sourceKey: sourceKey,
            sourceKind: "transcript_backfill",
            path: transcriptPath
        )
        checkpoint = try IngestSourceCheckpointStore.reconcileWithCurrentFile(
            database: database,
            checkpoint: checkpoint,
            path: transcriptPath
        )

        do {
            let deltaResult = try CodexTranscriptBackfillAdapter.scanTranscriptDelta(
                from: transcriptPath,
                startingAt: checkpoint.lastOffset,
                startingLineNumber: checkpoint.lastLineNumber,
                config: CodexTranscriptBackfillAdapterConfig(sessionIDFallback: providerSessionID)
            )
            let resolvedSessionID = deltaResult.sessionID ?? providerSessionID

            if deltaResult.events.isEmpty {
                if deltaResult.encounteredTokenCount == false, checkpoint.lastOffset > 0 || checkpoint.lastLineNumber > 0 {
                    try advanceCheckpointIfNeeded(
                        database: database,
                        checkpoint: checkpoint,
                        transcriptPath: transcriptPath,
                        result: deltaResult
                    )
                    try upsertBackfillHealth(
                        database: database,
                        healthState: "experimental",
                        message: "Codex transcript observed with no new token_count samples",
                        lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                        lastErrorAt: nil,
                        lastErrorSummary: nil
                    )
                    return CodexTranscriptBackfillResult(
                        backfillRunID: 0,
                        sessionID: resolvedSessionID,
                        status: "noop",
                        samplesExamined: 0,
                        samplesCreated: 0,
                        duplicatesSkipped: 0,
                        errorsCount: 0,
                        summaryJSON: "{\"provider\":\"codex\",\"mode\":\"transcript_backfill\",\"status\":\"noop\",\"reason\":\"no_new_token_count\"}"
                    )
                }

                throw CodexTranscriptBackfillAdapterError.noUsageSamplesFound
            }

            if deltaResult.encounteredTokenCount == false {
                if checkpoint.lastOffset == 0, checkpoint.lastLineNumber == 0 {
                    throw CodexTranscriptBackfillAdapterError.noUsageSamplesFound
                }

                try advanceCheckpointIfNeeded(
                    database: database,
                    checkpoint: checkpoint,
                    transcriptPath: transcriptPath,
                    result: deltaResult
                )
                try upsertBackfillHealth(
                    database: database,
                    healthState: "experimental",
                    message: "Codex transcript observed with no new token_count samples",
                    lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                    lastErrorAt: nil,
                    lastErrorSummary: nil
                )
                return CodexTranscriptBackfillResult(
                    backfillRunID: 0,
                    sessionID: resolvedSessionID,
                    status: "noop",
                    samplesExamined: 0,
                    samplesCreated: 0,
                    duplicatesSkipped: 0,
                    errorsCount: 0,
                    summaryJSON: "{\"provider\":\"codex\",\"mode\":\"transcript_backfill\",\"status\":\"noop\",\"reason\":\"no_new_token_count\"}"
                )
            }

            let ingestService = UsageSampleIngestionService(databasePath: databasePath)
            let ingestResult = try ingestService.ingestProviderEvents(
                database: database,
                events: deltaResult.events,
                sourceKey: sourceKey,
                sourcePath: transcriptPath,
                sourceKind: "recovery_scan",
                manageSourceCheckpoint: false
            )

            try advanceCheckpointIfNeeded(
                database: database,
                checkpoint: checkpoint,
                transcriptPath: transcriptPath,
                result: deltaResult
            )

            let samplesExamined = Int64(deltaResult.events.count)
            let samplesCreated = Int64(ingestResult.usageSamplesCreated)
            let duplicatesSkipped = Int64(ingestResult.duplicateEvents)
            let errorsCount = Int64(ingestResult.rejectedEvents)

            if samplesCreated == 0, duplicatesSkipped > 0, errorsCount == 0 {
                try upsertBackfillHealth(
                    database: database,
                    healthState: "experimental",
                    message: "Codex transcript checkpoint advanced; all appended samples were duplicates",
                    lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                    lastErrorAt: nil,
                    lastErrorSummary: nil
                )
                return CodexTranscriptBackfillResult(
                    backfillRunID: 0,
                    sessionID: resolvedSessionID,
                    status: "noop",
                    samplesExamined: samplesExamined,
                    samplesCreated: 0,
                    duplicatesSkipped: duplicatesSkipped,
                    errorsCount: 0,
                    summaryJSON: "{\"provider\":\"codex\",\"mode\":\"transcript_backfill\",\"status\":\"noop\",\"reason\":\"duplicates_only\",\"duplicates_skipped\":\(duplicatesSkipped)}"
                )
            }

            let backfillRunID = try BackfillRunStore.startBackfillRun(
                database: database,
                provider: .codex,
                providerSessionID: resolvedSessionID,
                mode: "transcript_backfill"
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.backfillStarted(
                    runID: backfillRunID,
                    provider: .codex,
                    sessionID: resolvedSessionID,
                    reason: "Recover Codex interactive token_count samples from transcript"
                )
            )

            let summaryJSON = try encodeSummary(
                CodexTranscriptBackfillSummary(
                    provider: ProviderCode.codex.rawValue,
                    mode: "transcript_backfill",
                    sessionID: resolvedSessionID,
                    transcriptPath: transcriptPath,
                    samplesExamined: samplesExamined,
                    samplesCreated: samplesCreated,
                    duplicatesSkipped: duplicatesSkipped,
                    errorsCount: errorsCount
                )
            )

            _ = try BackfillRunStore.completeBackfillRun(
                database: database,
                backfillRunID: backfillRunID,
                provider: .codex,
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
                    provider: .codex,
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
                message: "Codex transcript backfill completed; interactive support remains experimental",
                lastSuccessAt: ISO8601DateFormatter().string(from: Date()),
                lastErrorAt: nil,
                lastErrorSummary: nil
            )

            return CodexTranscriptBackfillResult(
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
                CodexTranscriptBackfillFailureSummary(
                    provider: ProviderCode.codex.rawValue,
                    mode: "transcript_backfill",
                    sessionID: providerSessionID,
                    transcriptPath: transcriptPath,
                    reason: error.localizedDescription
                )
            )

            let backfillRunID = try BackfillRunStore.startBackfillRun(
                database: database,
                provider: .codex,
                providerSessionID: providerSessionID,
                mode: "transcript_backfill"
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.backfillStarted(
                    runID: backfillRunID,
                    provider: .codex,
                    sessionID: providerSessionID,
                    reason: "Recover Codex interactive token_count samples from transcript"
                )
            )

            try upsertBackfillHealth(
                database: database,
                healthState: "degraded",
                message: "Codex transcript backfill failed",
                lastSuccessAt: nil,
                lastErrorAt: ISO8601DateFormatter().string(from: Date()),
                lastErrorSummary: error.localizedDescription
            )

            _ = try BackfillRunStore.completeBackfillRun(
                database: database,
                backfillRunID: backfillRunID,
                provider: .codex,
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
                    provider: .codex,
                    sessionID: providerSessionID,
                    samplesExamined: 0,
                    samplesCreated: 0,
                    duplicatesSkipped: 0,
                    errorsCount: 1
                )
            )

            throw error
        }
    }

    private static func sourceKey(transcriptPath: String) -> String {
        "recovery:codex:transcript:\(URL(fileURLWithPath: transcriptPath).path)"
    }

    private static func advanceCheckpointIfNeeded(
        database: SQLiteDatabase,
        checkpoint: IngestSourceCheckpoint,
        transcriptPath: String,
        result: CodexTranscriptBackfillDeltaResult
    ) throws {
        guard
            result.lastOffset != checkpoint.lastOffset
                || result.lastLineNumber != checkpoint.lastLineNumber
                || result.lastEventFingerprint != checkpoint.lastEventFingerprint
        else {
            return
        }

        try IngestSourceCheckpointStore.advance(
            database: database,
            sourceID: checkpoint.ingestSourceID,
            path: transcriptPath,
            offset: result.lastOffset,
            lineNumber: result.lastLineNumber,
            fingerprint: result.lastEventFingerprint
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
                .text(ProviderCode.codex.rawValue),
                .text("codex_transcript_backfill"),
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
