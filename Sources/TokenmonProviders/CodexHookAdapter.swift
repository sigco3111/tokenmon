import Foundation

public struct CodexHookPayload: Decodable, Sendable {
    public let sessionID: String
    public let transcriptPath: String?
    public let cwd: String?
    public let hookEventName: String
    public let model: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case model
        case message
    }
}

public struct CodexHookImportResult: Sendable {
    public let hookEventName: String
    public let sessionID: String
    public let transcriptPath: String?
    public let model: String?
}

public enum CodexHookAdapter {
    public static func importPayload(json: String) throws -> CodexHookImportResult {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(CodexHookPayload.self, from: Data(json.utf8))

        return CodexHookImportResult(
            hookEventName: payload.hookEventName,
            sessionID: payload.sessionID,
            transcriptPath: payload.transcriptPath,
            model: payload.model
        )
    }
}
