import Foundation

public struct ClaudeHookPayload: Decodable, Sendable {
    public let sessionID: String
    public let transcriptPath: String?
    public let cwd: String?
    public let hookEventName: String
    public let message: String?
    public let reason: String?
    public let model: ClaudeStatusLineModel?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case message
        case reason
        case model
    }
}

public enum ClaudeHookKind: String, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case notification = "Notification"
}

public struct ClaudeHookImportResult: Sendable {
    public let hookEventName: String
    public let sessionID: String
    public let transcriptPath: String?
    public let message: String?
}

public enum ClaudeHookAdapterError: Error, LocalizedError {
    case unsupportedHookEvent(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedHookEvent(let value):
            return "unsupported Claude hook event: \(value)"
        }
    }
}

public enum ClaudeHookAdapter {
    public static func importPayload(json: String) throws -> ClaudeHookImportResult {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ClaudeHookPayload.self, from: Data(json.utf8))

        guard ClaudeHookKind(rawValue: payload.hookEventName) != nil else {
            throw ClaudeHookAdapterError.unsupportedHookEvent(payload.hookEventName)
        }

        return ClaudeHookImportResult(
            hookEventName: payload.hookEventName,
            sessionID: payload.sessionID,
            transcriptPath: payload.transcriptPath,
            message: payload.message ?? payload.reason
        )
    }
}
