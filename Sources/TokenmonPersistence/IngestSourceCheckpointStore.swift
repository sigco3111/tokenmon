import Foundation

struct IngestSourceCheckpoint: Equatable, Sendable {
    let ingestSourceID: Int64
    let lastOffset: Int64
    let lastLineNumber: Int
    let lastEventFingerprint: String?
    let lastSeenAt: String?

    var reset: IngestSourceCheckpoint {
        IngestSourceCheckpoint(
            ingestSourceID: ingestSourceID,
            lastOffset: 0,
            lastLineNumber: 0,
            lastEventFingerprint: nil,
            lastSeenAt: lastSeenAt
        )
    }
}

enum IngestSourceCheckpointStore {
    static func loadOrCreate(
        database: SQLiteDatabase,
        sourceKey: String,
        sourceKind: String,
        path: String?
    ) throws -> IngestSourceCheckpoint {
        let lookupSQL = """
        SELECT ingest_source_id,
               last_offset,
               last_line_number,
               last_event_fingerprint,
               last_seen_at
        FROM ingest_sources
        WHERE source_key = ?
        LIMIT 1;
        """

        if let existing = try database.fetchOne(
            lookupSQL,
            bindings: [.text(sourceKey)],
            map: { statement in
                IngestSourceCheckpoint(
                    ingestSourceID: SQLiteDatabase.columnInt64(statement, index: 0),
                    lastOffset: SQLiteDatabase.columnInt64(statement, index: 1),
                    lastLineNumber: Int(SQLiteDatabase.columnInt64(statement, index: 2)),
                    lastEventFingerprint: SQLiteDatabase.columnOptionalText(statement, index: 3),
                    lastSeenAt: SQLiteDatabase.columnOptionalText(statement, index: 4)
                )
            }
        ) {
            return existing
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO ingest_sources (
                source_key,
                source_kind,
                source_path,
                last_offset,
                last_line_number,
                last_event_fingerprint,
                last_seen_at,
                updated_at
            ) VALUES (?, ?, ?, 0, 0, NULL, NULL, ?);
            """,
            bindings: [
                .text(sourceKey),
                .text(sourceKind),
                path.map(SQLiteValue.text) ?? .null,
                .text(now),
            ]
        )

        return IngestSourceCheckpoint(
            ingestSourceID: database.lastInsertRowID(),
            lastOffset: 0,
            lastLineNumber: 0,
            lastEventFingerprint: nil,
            lastSeenAt: nil
        )
    }

    static func advance(
        database: SQLiteDatabase,
        sourceID: Int64,
        path: String?,
        offset: Int64,
        lineNumber: Int,
        fingerprint: String?
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE ingest_sources
            SET source_path = ?,
                last_offset = ?,
                last_line_number = ?,
                last_event_fingerprint = ?,
                last_seen_at = ?,
                updated_at = ?
            WHERE ingest_source_id = ?;
            """,
            bindings: [
                path.map(SQLiteValue.text) ?? .null,
                .integer(offset),
                .integer(Int64(lineNumber)),
                fingerprint.map(SQLiteValue.text) ?? .null,
                .text(now),
                .text(now),
                .integer(sourceID),
            ]
        )
    }

    static func reconcileWithCurrentFile(
        database: SQLiteDatabase,
        checkpoint: IngestSourceCheckpoint,
        path: String
    ) throws -> IngestSourceCheckpoint {
        guard checkpoint.lastOffset > 0 else {
            return checkpoint
        }

        let fileURL = URL(fileURLWithPath: path)
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fileSize = Int64(resourceValues.fileSize ?? 0)

        let shouldResetForTruncation = fileSize < checkpoint.lastOffset
        let shouldResetForReplacement: Bool

        if shouldResetForTruncation {
            shouldResetForReplacement = false
        } else if let modificationDate = resourceValues.contentModificationDate,
                  fileModificationDate(modificationDate, isLaterThan: checkpoint.lastSeenAt)
        {
            shouldResetForReplacement = try checkpointFingerprintMissingNearOffset(
                path: path,
                offset: min(fileSize, checkpoint.lastOffset),
                fingerprint: checkpoint.lastEventFingerprint
            )
        } else {
            shouldResetForReplacement = false
        }

        guard shouldResetForTruncation || shouldResetForReplacement else {
            return checkpoint
        }

        try advance(
            database: database,
            sourceID: checkpoint.ingestSourceID,
            path: path,
            offset: 0,
            lineNumber: 0,
            fingerprint: nil
        )
        return checkpoint.reset
    }

    private static func checkpointFingerprintMissingNearOffset(
        path: String,
        offset: Int64,
        fingerprint: String?
    ) throws -> Bool {
        guard let fingerprint, fingerprint.isEmpty == false else {
            return true
        }

        let fileData = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        let upperBound = min(fileData.count, max(0, Int(offset)))
        let lowerBound = max(0, upperBound - 8_192)
        let window = fileData[lowerBound..<upperBound]
        let renderedWindow = String(decoding: window, as: UTF8.self)

        return renderedWindow.contains(fingerprint) == false
    }

    private static func fileModificationDate(_ fileDate: Date, isLaterThan timestamp: String?) -> Bool {
        guard let seenDate = parseISO8601(timestamp) else {
            return true
        }

        return fileDate > seenDate
    }

    private static func parseISO8601(_ value: String?) -> Date? {
        guard let value, value.isEmpty == false else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }
}
