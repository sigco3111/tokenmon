import Foundation
import OSLog
import TokenmonPersistence

enum TokenmonAppLogLevel: String, Codable, Equatable, Sendable {
    case debug
    case info
    case notice
    case error
}

struct TokenmonAppLogEntry: Codable, Equatable, Sendable {
    let timestamp: String
    let level: TokenmonAppLogLevel
    let category: String
    let event: String
    let metadata: [String: String]
}

enum TokenmonAppBehaviorLogger {
    private enum Constants {
        static let maxBytes = 256 * 1024
        static let maxEntries = 400
        static let recentEntryLimit = 120
    }

    private static let queue = DispatchQueue(label: "TokenmonApp.AppBehaviorLogger")

    static func logsDirectoryPath(supportDirectoryPath: String) -> String {
        URL(fileURLWithPath: supportDirectoryPath, isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .path
    }

    static func logFilePath(supportDirectoryPath: String) -> String {
        URL(fileURLWithPath: logsDirectoryPath(supportDirectoryPath: supportDirectoryPath), isDirectory: true)
            .appendingPathComponent("app-events.ndjson")
            .path
    }

    static func recentEntries(
        supportDirectoryPath: String,
        limit: Int = Constants.recentEntryLimit
    ) -> [TokenmonAppLogEntry] {
        let filePath = logFilePath(supportDirectoryPath: supportDirectoryPath)
        return queue.sync {
            guard let data = FileManager.default.contents(atPath: filePath), data.isEmpty == false else {
                return []
            }

            let decoder = JSONDecoder()
            let lines = String(decoding: data, as: UTF8.self)
                .split(separator: "\n")
                .suffix(max(0, limit))

            return lines.compactMap { line in
                try? decoder.decode(TokenmonAppLogEntry.self, from: Data(line.utf8))
            }
        }
    }

    static func durationMillisecondsString(since startedAt: Date, until finishedAt: Date = Date()) -> String {
        let milliseconds = Int((finishedAt.timeIntervalSince(startedAt) * 1000).rounded())
        return String(max(0, milliseconds))
    }

    static func debug(
        category: String,
        event: String,
        metadata: [String: String] = [:],
        supportDirectoryPath: String
    ) {
        write(level: .debug, category: category, event: event, metadata: metadata, supportDirectoryPath: supportDirectoryPath)
    }

    static func info(
        category: String,
        event: String,
        metadata: [String: String] = [:],
        supportDirectoryPath: String
    ) {
        write(level: .info, category: category, event: event, metadata: metadata, supportDirectoryPath: supportDirectoryPath)
    }

    static func notice(
        category: String,
        event: String,
        metadata: [String: String] = [:],
        supportDirectoryPath: String
    ) {
        write(level: .notice, category: category, event: event, metadata: metadata, supportDirectoryPath: supportDirectoryPath)
    }

    static func error(
        category: String,
        event: String,
        metadata: [String: String] = [:],
        supportDirectoryPath: String
    ) {
        write(level: .error, category: category, event: event, metadata: metadata, supportDirectoryPath: supportDirectoryPath)
    }

    private static func write(
        level: TokenmonAppLogLevel,
        category: String,
        event: String,
        metadata: [String: String],
        supportDirectoryPath: String
    ) {
        let entry = TokenmonAppLogEntry(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            level: level,
            category: category,
            event: event,
            metadata: metadata
        )
        let message = renderMessage(for: entry)
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.aroido.tokenmon",
            category: category
        )

        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .notice:
            logger.notice("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }

        queue.async {
            let fileManager = FileManager.default
            let logsDirectoryPath = logsDirectoryPath(supportDirectoryPath: supportDirectoryPath)
            let filePath = logFilePath(supportDirectoryPath: supportDirectoryPath)

            do {
                try fileManager.createDirectory(
                    atPath: logsDirectoryPath,
                    withIntermediateDirectories: true
                )

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                var data = try encoder.encode(entry)
                data.append(0x0A)

                if fileManager.fileExists(atPath: filePath) == false {
                    fileManager.createFile(atPath: filePath, contents: data)
                } else if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: filePath)) {
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                }

                try trimIfNeeded(filePath: filePath)
            } catch {
                return
            }
        }
    }

    private static func trimIfNeeded(filePath: String) throws {
        let fileManager = FileManager.default
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: filePath),
            let size = attributes[.size] as? NSNumber,
            size.intValue > Constants.maxBytes,
            let data = fileManager.contents(atPath: filePath)
        else {
            return
        }

        let lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
        let retained = lines.suffix(Constants.maxEntries)
        let trimmedData = retained.joined(separator: "\n").appending("\n").data(using: .utf8) ?? Data()
        try trimmedData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
    }

    private static func renderMessage(for entry: TokenmonAppLogEntry) -> String {
        if entry.metadata.isEmpty {
            return entry.event
        }

        let metadata = entry.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(entry.event) | \(metadata)"
    }
}
