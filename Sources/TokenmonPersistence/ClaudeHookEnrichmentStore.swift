import Foundation
import TokenmonDomain
import TokenmonProviders

public struct ClaudeHookEnrichmentResult: Sendable {
    public let hookEventName: String
    public let providerSessionID: String
    public let providerSessionRowID: Int64
    public let sessionState: String
    public let healthState: String
}

public enum ClaudeHookEnrichmentStore {
    public static func apply(
        databasePath: String,
        payload: ClaudeHookPayload,
        observedAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> ClaudeHookEnrichmentResult {
        let database = try TokenmonDatabaseManager(path: databasePath).open()
        return try apply(database: database, payload: payload, observedAt: observedAt)
    }

    public static func apply(
        database: SQLiteDatabase,
        payload: ClaudeHookPayload,
        observedAt: String
    ) throws -> ClaudeHookEnrichmentResult {
        let hookKind = ClaudeHookKind(rawValue: payload.hookEventName) ?? .notification
        let now = ISO8601DateFormatter().string(from: Date())
        let sessionState = hookKind == .sessionEnd ? "ended" : "active"
        let healthState: String
        let message: String

        switch hookKind {
        case .sessionStart:
            healthState = "active"
            message = "Claude hooks active via SessionStart"
        case .sessionEnd:
            healthState = "connected"
            message = "Claude session ended via SessionEnd"
        case .notification:
            healthState = "connected"
            message = payload.message ?? "Claude hook notification received"
        }

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
                .text(ProviderCode.claude.rawValue),
                .text(payload.sessionID),
                .text("claude_hooks_enrichment"),
                payload.model?.id.map(SQLiteValue.text) ?? payload.model?.displayName.map(SQLiteValue.text) ?? .null,
                payload.cwd.map(SQLiteValue.text) ?? .null,
                payload.transcriptPath.map(SQLiteValue.text) ?? .null,
                hookKind == .sessionStart ? .text(observedAt) : .null,
                hookKind == .sessionEnd ? .text(observedAt) : .null,
                .text(observedAt),
                .text(sessionState),
                .text(now),
                .text(now),
            ]
        )

        let sessionRowID = try database.fetchOne(
            """
            SELECT provider_session_row_id
            FROM provider_sessions
            WHERE provider_code = ? AND provider_session_id = ?
            LIMIT 1;
            """,
            bindings: [.text(ProviderCode.claude.rawValue), .text(payload.sessionID)]
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0

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
                .text(ProviderCode.claude.rawValue),
                .text("claude_hooks_enrichment"),
                .text(healthState),
                .text(message),
                .text(observedAt),
                .text(now),
            ]
        )

        return ClaudeHookEnrichmentResult(
            hookEventName: payload.hookEventName,
            providerSessionID: payload.sessionID,
            providerSessionRowID: sessionRowID,
            sessionState: sessionState,
            healthState: healthState
        )
    }
}
