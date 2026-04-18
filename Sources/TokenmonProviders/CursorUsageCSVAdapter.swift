import CryptoKit
import Foundation
import TokenmonDomain

public struct CursorUsageCSVImportResult: Sendable {
    public let sourcePath: String
    public let outputPath: String?
    public let linesRead: Int
    public let eventsWritten: Int
}

private struct CursorUsageCSVRow {
    let index: Int
    let observedAt: String
    let cloudAgentID: String?
    let automationID: String?
    let kind: String
    let modelSlug: String
    let maxMode: String?
    let inputTokens: Int64
    let cacheWriteTokens: Int64
    let cacheReadTokens: Int64
    let outputTokens: Int64
    let totalTokens: Int64
    let costUSD: Double

    var sessionKey: String {
        if let cloudAgentID, cloudAgentID.isEmpty == false {
            return "cloud-agent:\(cloudAgentID)"
        }
        if let automationID, automationID.isEmpty == false {
            return "automation:\(automationID)"
        }
        return "cursor-\(kind)"
    }

    var totalCachedTokens: Int64 {
        cacheWriteTokens + cacheReadTokens
    }
}

public enum CursorUsageCSVAdapterError: Error, LocalizedError {
    case invalidCSVHeader

    public var errorDescription: String? {
        switch self {
        case .invalidCSVHeader:
            return "cursor usage export does not include the expected Date/Model columns"
        }
    }
}

public enum CursorUsageCSVAdapter {
    public static func importCSV(
        from sourcePath: String,
        outputPath: String? = nil
    ) throws -> CursorUsageCSVImportResult {
        let rows = try parseRows(from: sourcePath)
        let events = providerEvents(from: rows)
        try write(events: events, to: outputPath)

        return CursorUsageCSVImportResult(
            sourcePath: sourcePath,
            outputPath: outputPath,
            linesRead: rows.count,
            eventsWritten: events.count
        )
    }

    public static func providerEvents(from sourcePath: String) throws -> [ProviderUsageSampleEvent] {
        providerEvents(from: try parseRows(from: sourcePath))
    }

    private static func parseRows(from sourcePath: String) throws -> [CursorUsageCSVRow] {
        let content = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let lines = content.split(whereSeparator: \.isNewline).map(String.init)
        guard let headerLine = lines.first else {
            return []
        }

        let headerFields = parseCSVLine(headerLine)
        let headerLookup = Dictionary(uniqueKeysWithValues: headerFields.enumerated().map { ($1, $0) })

        guard headerLookup["Date"] != nil, headerLookup["Model"] != nil else {
            throw CursorUsageCSVAdapterError.invalidCSVHeader
        }

        var rows: [CursorUsageCSVRow] = []
        for (lineOffset, rawLine) in lines.dropFirst().enumerated() {
            let fields = parseCSVLine(rawLine)
            let rowIndex = lineOffset + 1

            let observedAt = stringField("Date", fields, headerLookup)
            let modelSlug = stringField("Model", fields, headerLookup)
            guard observedAt.isEmpty == false, modelSlug.isEmpty == false else {
                continue
            }

            let inputWithCacheWrite = intField("Input (w/ Cache Write)", fields, headerLookup)
            let inputWithoutCacheWrite = intField("Input (w/o Cache Write)", fields, headerLookup)
            let cacheReadTokens = intField("Cache Read", fields, headerLookup)
            let outputTokens = intField("Output Tokens", fields, headerLookup)
            let totalTokensField = intField("Total Tokens", fields, headerLookup)
            let cacheWriteTokens = max(0, inputWithCacheWrite - inputWithoutCacheWrite)
            let totalTokens = totalTokensField > 0
                ? totalTokensField
                : inputWithoutCacheWrite + cacheWriteTokens + cacheReadTokens + outputTokens

            rows.append(
                CursorUsageCSVRow(
                    index: rowIndex,
                    observedAt: observedAt,
                    cloudAgentID: optionalField("Cloud Agent ID", fields, headerLookup),
                    automationID: optionalField("Automation ID", fields, headerLookup),
                    kind: optionalField("Kind", fields, headerLookup) ?? "usage",
                    modelSlug: modelSlug,
                    maxMode: optionalField("Max Mode", fields, headerLookup),
                    inputTokens: inputWithoutCacheWrite,
                    cacheWriteTokens: cacheWriteTokens,
                    cacheReadTokens: cacheReadTokens,
                    outputTokens: outputTokens,
                    totalTokens: totalTokens,
                    costUSD: costField("Cost", fields, headerLookup)
                )
            )
        }

        return rows.sorted {
            if $0.observedAt == $1.observedAt {
                return $0.index < $1.index
            }
            return $0.observedAt < $1.observedAt
        }
    }

    private static func providerEvents(from rows: [CursorUsageCSVRow]) -> [ProviderUsageSampleEvent] {
        var cumulativeTotalsBySessionKey: [String: Int64] = [:]

        return rows.map { row in
            let cumulativeTotal = cumulativeTotalsBySessionKey[row.sessionKey, default: 0] + row.totalTokens
            cumulativeTotalsBySessionKey[row.sessionKey] = cumulativeTotal

            return ProviderUsageSampleEvent(
                eventType: "provider_usage_sample",
                provider: .cursor,
                sourceMode: "cursor_usage_export_api",
                providerSessionID: row.sessionKey,
                observedAt: row.observedAt,
                workspaceDir: nil,
                modelSlug: row.modelSlug,
                transcriptPath: nil,
                totalInputTokens: row.inputTokens,
                totalOutputTokens: row.outputTokens,
                totalCachedInputTokens: row.totalCachedTokens,
                normalizedTotalTokens: cumulativeTotal,
                providerEventFingerprint: providerFingerprint(for: row),
                rawReference: ProviderRawReference(
                    kind: "cursor_usage_csv",
                    offset: "\(row.index)",
                    eventName: row.kind
                ),
                currentInputTokens: row.inputTokens,
                currentOutputTokens: row.outputTokens,
                sessionOriginHint: .startedDuringLiveRuntime
            )
        }
    }

    private static func providerFingerprint(for row: CursorUsageCSVRow) -> String {
        let payload = [
            row.observedAt,
            row.cloudAgentID ?? "",
            row.automationID ?? "",
            row.kind,
            row.modelSlug,
            row.maxMode ?? "",
            "\(row.inputTokens)",
            "\(row.cacheWriteTokens)",
            "\(row.cacheReadTokens)",
            "\(row.outputTokens)",
            "\(row.totalTokens)",
            "\(row.costUSD)",
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(payload.utf8))
        let digestText = digest.map { String(format: "%02x", $0) }.joined()
        return "cursor:\(row.sessionKey):\(digestText)"
    }

    private static func write(events: [ProviderUsageSampleEvent], to outputPath: String?) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        if let outputPath {
            let outputURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var buffer = Data()
            for event in events {
                buffer.append(try encoder.encode(event))
                buffer.append(0x0A)
            }
            try buffer.write(to: outputURL)
            return
        }

        for event in events {
            print(try String(decoding: encoder.encode(event), as: UTF8.self))
        }
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for character in line {
            switch character {
            case "\"":
                inQuotes.toggle()
            case "," where inQuotes == false:
                fields.append(current)
                current = ""
            default:
                current.append(character)
            }
        }

        fields.append(current)
        return fields
    }

    private static func stringField(
        _ name: String,
        _ fields: [String],
        _ headerLookup: [String: Int]
    ) -> String {
        guard let index = headerLookup[name], index < fields.count else {
            return ""
        }
        return fields[index].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private static func optionalField(
        _ name: String,
        _ fields: [String],
        _ headerLookup: [String: Int]
    ) -> String? {
        let value = stringField(name, fields, headerLookup)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func intField(
        _ name: String,
        _ fields: [String],
        _ headerLookup: [String: Int]
    ) -> Int64 {
        let value = stringField(name, fields, headerLookup)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int64(value) ?? 0
    }

    private static func costField(
        _ name: String,
        _ fields: [String],
        _ headerLookup: [String: Int]
    ) -> Double {
        let value = stringField(name, fields, headerLookup)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard value.isEmpty == false,
              value.caseInsensitiveCompare("nan") != .orderedSame,
              value.caseInsensitiveCompare("included") != .orderedSame,
              value != "-" else {
            return 0
        }

        return Double(value) ?? 0
    }
}
