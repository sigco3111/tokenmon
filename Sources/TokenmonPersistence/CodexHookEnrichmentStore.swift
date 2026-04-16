import Foundation
import TokenmonDomain
import TokenmonProviders

public struct CodexHookEnrichmentResult: Sendable {
    public let hookEventName: String
    public let providerSessionID: String
    public let providerSessionRowID: Int64
    public let sessionState: String
    public let healthState: String
    public let transcriptBackfillStatus: String?
}

public enum CodexHookEnrichmentStore {
    public static func apply(
        databasePath: String,
        payload: CodexHookPayload,
        observedAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> CodexHookEnrichmentResult {
        let database = try TokenmonDatabaseManager(path: databasePath).open()
        return try apply(
            databasePath: databasePath,
            database: database,
            payload: payload,
            observedAt: observedAt
        )
    }

    public static func apply(
        databasePath: String,
        database: SQLiteDatabase,
        payload: CodexHookPayload,
        observedAt: String
    ) throws -> CodexHookEnrichmentResult {
        let now = ISO8601DateFormatter().string(from: Date())
        let isSessionEnd = payload.hookEventName == "SessionEnd" || payload.hookEventName == "Stop"
        let transcriptPath = resolvedTranscriptPath(database: database, payload: payload)
        let sessionState = isSessionEnd ? "ended" : "active"
        let healthState = "experimental"
        let message = "Codex interactive hooks detected; token capture is experimental"

        try database.execute(
            """
            INSERT INTO provider_sessions (
                provider_code,
                provider_session_id,
                session_identity_kind,
                source_mode,
                model_slug,
                workspace_dir,
                transcript_path,
                started_at,
                ended_at,
                last_seen_at,
                session_state,
                created_at,
                updated_at
            ) VALUES (?, ?, 'authoritative', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(provider_code, provider_session_id) DO UPDATE SET
                source_mode = excluded.source_mode,
                model_slug = COALESCE(excluded.model_slug, provider_sessions.model_slug),
                workspace_dir = COALESCE(excluded.workspace_dir, provider_sessions.workspace_dir),
                transcript_path = COALESCE(excluded.transcript_path, provider_sessions.transcript_path),
                started_at = COALESCE(provider_sessions.started_at, excluded.started_at),
                ended_at = excluded.ended_at,
                last_seen_at = excluded.last_seen_at,
                session_state = excluded.session_state,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(ProviderCode.codex.rawValue),
                .text(payload.sessionID),
                .text("codex_interactive_hook_assisted"),
                payload.model.map(SQLiteValue.text) ?? .null,
                payload.cwd.map(SQLiteValue.text) ?? .null,
                transcriptPath.map(SQLiteValue.text) ?? .null,
                isSessionEnd ? .null : .text(observedAt),
                isSessionEnd ? .text(observedAt) : .null,
                .text(observedAt),
                .text(sessionState),
                .text(now),
                .text(now),
            ]
        )

        let sessionRowID = try database.fetchOne(
            """
            SELECT provider_session_row_id, transcript_path
            FROM provider_sessions
            WHERE provider_code = ? AND provider_session_id = ?
            LIMIT 1;
            """,
            bindings: [.text(ProviderCode.codex.rawValue), .text(payload.sessionID)]
        ) { statement in
            (
                SQLiteDatabase.columnInt64(statement, index: 0),
                SQLiteDatabase.columnOptionalText(statement, index: 1)
            )
        } ?? (0, nil)

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
            ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, ?)
            ON CONFLICT(provider_code, source_mode) DO UPDATE SET
                health_state = excluded.health_state,
                message = excluded.message,
                last_success_at = excluded.last_success_at,
                last_error_at = NULL,
                last_error_code = NULL,
                last_error_summary = NULL,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(ProviderCode.codex.rawValue),
                .text("codex_interactive_hook_assisted"),
                .text(healthState),
                .text(message),
                .text(observedAt),
                .text(now),
            ]
        )

        let transcriptBackfillStatus: String?
        if isSessionEnd, let transcriptPath = sessionRowID.1, transcriptPath.isEmpty == false {
            do {
                try ProviderBackfillRequestQueue.enqueue(
                    databasePath: databasePath,
                    request: ProviderBackfillRequest(
                        provider: .codex,
                        providerSessionID: payload.sessionID,
                        transcriptPath: transcriptPath,
                        requestedAt: observedAt
                    )
                )
                transcriptBackfillStatus = "queued"
            } catch {
                transcriptBackfillStatus = "failed"
            }
        } else {
            transcriptBackfillStatus = nil
        }

        return CodexHookEnrichmentResult(
            hookEventName: payload.hookEventName,
            providerSessionID: payload.sessionID,
            providerSessionRowID: sessionRowID.0,
            sessionState: sessionState,
            healthState: healthState,
            transcriptBackfillStatus: transcriptBackfillStatus
        )
    }

    private static func resolvedTranscriptPath(
        database: SQLiteDatabase,
        payload: CodexHookPayload
    ) -> String? {
        if let transcriptPath = payload.transcriptPath?.trimmedNonEmpty {
            return transcriptPath
        }

        return CodexSessionStorageLocator.resolveTranscriptPath(
            sessionID: payload.sessionID,
            config: CodexSessionStorageLocatorConfig(
                configurationRootPath: codexConfigurationRootPath(database: database)
            )
        )
    }

    private static func codexConfigurationRootPath(database: SQLiteDatabase) -> String? {
        guard let rawJSON = try? database.fetchOne(
            """
            SELECT setting_value_json
            FROM settings
            WHERE setting_key = 'provider_installation_preferences'
            LIMIT 1;
            """,
            map: { statement in
                SQLiteDatabase.columnText(statement, index: 0)
            }
        ) else {
            return nil
        }

        let decoder = JSONDecoder()
        let preferences = try? decoder.decode(ProviderInstallationPreferences.self, from: Data(rawJSON.utf8))
        return preferences?.codex.configurationPath?.trimmedNonEmpty
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
