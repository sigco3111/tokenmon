import CryptoKit
import Foundation
import SQLite3
import TokenmonDomain

public enum OpenCodeSQLiteAdapterError: Error, LocalizedError {
    case databaseNotFound(String)
    case databaseOpenFailed(String)
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "opencode database not found at \(path)"
        case .databaseOpenFailed(let detail):
            return "failed to open opencode database: \(detail)"
        case .queryFailed(let detail):
            return "opencode database query failed: \(detail)"
        }
    }
}

private struct OpenCodeMessageData: Decodable {
    let role: String?
    let tokens: OpenCodeTokens?
    let cost: Double?
    let providerID: String?
    let modelID: String?
    let path: OpenCodePath?
    let time: OpenCodeTime?
}

private struct OpenCodeTokens: Decodable {
    let input: Int64?
    let output: Int64?
    let reasoning: Int64?
    let cache: OpenCodeCache?
    let total: Int64?
}

private struct OpenCodeCache: Decodable {
    let read: Int64?
    let write: Int64?
}

private struct OpenCodePath: Decodable {
    let cwd: String?
}

private struct OpenCodeTime: Decodable {
    let created: Int64?
}

private struct OpenCodeMessageRow {
    let id: String
    let sessionID: String
    let timeCreated: Int64
    let dataString: String
}

public enum OpenCodeSQLiteAdapter {
    public static func providerEvents(from dbPath: String) throws -> [ProviderUsageSampleEvent] {
        try providerEvents(from: dbPath, since: nil)
    }

    public static func providerEvents(
        from dbPath: String,
        since messageID: String?
    ) throws -> [ProviderUsageSampleEvent] {
        let db = try openDatabase(at: dbPath)
        defer { sqlite3_close(db) }

        let messages = try fetchMessages(from: db, since: messageID)
        return buildEvents(from: messages)
    }

    private static func openDatabase(at path: String) throws -> OpaquePointer {
        guard FileManager.default.fileExists(atPath: path) else {
            throw OpenCodeSQLiteAdapterError.databaseNotFound(path)
        }
        var db: OpaquePointer?
        let result = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK, let db else {
            sqlite3_close(db)
            throw OpenCodeSQLiteAdapterError.databaseOpenFailed(
                "sqlite3_open_v2 returned \(result)"
            )
        }
        return db
    }

    private static func fetchMessages(
        from db: OpaquePointer,
        since messageID: String?
    ) throws -> [OpenCodeMessageRow] {
        let sql = """
            SELECT m.id, m.session_id, m.time_created, m.data
            FROM message m
            WHERE m.id > ?
            ORDER BY m.time_created ASC
            """

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(db))
            throw OpenCodeSQLiteAdapterError.queryFailed("prepare: \(message)")
        }
        defer { sqlite3_finalize(statement) }

        let sinceValue = messageID ?? ""
        let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let bindResult = sqlite3_bind_text(
            statement, 1, sinceValue, -1, transientDestructor
        )
        guard bindResult == SQLITE_OK else {
            throw OpenCodeSQLiteAdapterError.queryFailed("bind: code \(bindResult)")
        }

        var rows: [OpenCodeMessageRow] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_ROW {
                guard let idPtr = sqlite3_column_text(statement, 0),
                      let sessionIDPtr = sqlite3_column_text(statement, 1) else {
                    continue
                }

                let id = String(cString: idPtr)
                let sessionID = String(cString: sessionIDPtr)
                let timeCreated = sqlite3_column_int64(statement, 2)

                guard let dataPtr = sqlite3_column_text(statement, 3) else {
                    continue
                }
                let dataString = String(cString: dataPtr)

                rows.append(OpenCodeMessageRow(
                    id: id,
                    sessionID: sessionID,
                    timeCreated: timeCreated,
                    dataString: dataString
                ))
            } else if stepResult == SQLITE_DONE {
                break
            } else {
                let message = String(cString: sqlite3_errmsg(db))
                throw OpenCodeSQLiteAdapterError.queryFailed("step: \(message)")
            }
        }

        return rows
    }

    private static func buildEvents(
        from rows: [OpenCodeMessageRow]
    ) -> [ProviderUsageSampleEvent] {
        var cumulativeTotalsBySession: [String: Int64] = [:]
        var events: [ProviderUsageSampleEvent] = []

        for row in rows {
            let data: OpenCodeMessageData
            do {
                data = try JSONDecoder().decode(
                    OpenCodeMessageData.self,
                    from: Data(row.dataString.utf8)
                )
            } catch {
                continue
            }

            guard data.role == "assistant" else {
                continue
            }

            let inputTokens = data.tokens?.input ?? 0
            let outputTokens = data.tokens?.output ?? 0
            let cacheReadTokens = data.tokens?.cache?.read ?? 0
            let cacheWriteTokens = data.tokens?.cache?.write ?? 0
            let messageTotal = inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens

            let cumulativeTotal = cumulativeTotalsBySession[row.sessionID, default: 0] + messageTotal
            cumulativeTotalsBySession[row.sessionID] = cumulativeTotal

            let observedAt: String
            if let created = data.time?.created, created > 0 {
                observedAt = iso8601FromMilliseconds(created)
            } else {
                observedAt = iso8601FromMilliseconds(row.timeCreated)
            }

            let fingerprint = providerFingerprint(
                sessionID: row.sessionID,
                messageID: row.id,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheReadTokens: cacheReadTokens,
                cacheWriteTokens: cacheWriteTokens
            )

            events.append(
                ProviderUsageSampleEvent(
                    eventType: "provider_usage_sample",
                    provider: .opencode,
                    sourceMode: "opencode_sqlite_backfill",
                    providerSessionID: row.sessionID,
                    observedAt: observedAt,
                    workspaceDir: data.path?.cwd,
                    modelSlug: data.modelID,
                    transcriptPath: nil,
                    totalInputTokens: inputTokens,
                    totalOutputTokens: outputTokens,
                    totalCachedInputTokens: cacheReadTokens + cacheWriteTokens,
                    normalizedTotalTokens: cumulativeTotal,
                    providerEventFingerprint: fingerprint,
                    rawReference: ProviderRawReference(
                        kind: "opencode_sqlite_message",
                        offset: row.id,
                        eventName: "message"
                    ),
                    currentInputTokens: inputTokens,
                    currentOutputTokens: outputTokens,
                    sessionOriginHint: .unknown
                )
            )
        }

        return events
    }

    private static func iso8601FromMilliseconds(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        return ISO8601DateFormatter().string(from: date)
    }

    private static func providerFingerprint(
        sessionID: String,
        messageID: String,
        inputTokens: Int64,
        outputTokens: Int64,
        cacheReadTokens: Int64,
        cacheWriteTokens: Int64
    ) -> String {
        let payload = [
            sessionID,
            messageID,
            "\(inputTokens)",
            "\(outputTokens)",
            "\(cacheReadTokens)",
            "\(cacheWriteTokens)",
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(payload.utf8))
        let digestText = digest.map { String(format: "%02x", $0) }.joined()
        return "opencode:\(sessionID):\(digestText)"
    }
}
