import Foundation
import TokenmonDomain

public struct ProviderBackfillRequest: Equatable, Codable, Sendable {
    public let provider: ProviderCode
    public let providerSessionID: String
    public let transcriptPath: String
    public let requestedAt: String
}

public struct PendingProviderBackfillRequest: Equatable, Sendable {
    public let filePath: String
    public let request: ProviderBackfillRequest
}

public enum ProviderBackfillRequestQueue {
    public static func enqueue(
        databasePath: String,
        request: ProviderBackfillRequest
    ) throws {
        let directory = queueDirectory(databasePath: databasePath)
        let fileURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(filename(for: request), isDirectory: false)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(request)
        try data.write(to: fileURL, options: [.atomic])
    }

    public static func pendingRequests(
        databasePath: String
    ) throws -> [PendingProviderBackfillRequest] {
        let directory = queueDirectory(databasePath: databasePath)
        guard FileManager.default.fileExists(atPath: directory) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: directory, isDirectory: true),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let decoder = JSONDecoder()

        return try urls
            .filter { $0.pathExtension == "json" }
            .sorted {
                let lhsDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }
            .map { url in
                let data = try Data(contentsOf: url)
                let request = try decoder.decode(ProviderBackfillRequest.self, from: data)
                return PendingProviderBackfillRequest(filePath: url.path, request: request)
            }
    }

    public static func removeRequest(at filePath: String) {
        try? FileManager.default.removeItem(atPath: filePath)
    }

    private static func queueDirectory(databasePath: String) -> String {
        URL(
            fileURLWithPath: TokenmonDatabaseManager.supportDirectory(forDatabasePath: databasePath),
            isDirectory: true
        )
        .appendingPathComponent("BackfillRequests", isDirectory: true)
        .path
    }

    private static func filename(for request: ProviderBackfillRequest) -> String {
        let sanitizedSessionID = request.providerSessionID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(request.provider.rawValue)-\(sanitizedSessionID).json"
    }
}
