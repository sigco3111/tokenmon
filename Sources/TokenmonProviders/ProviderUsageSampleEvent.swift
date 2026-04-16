import Foundation
import TokenmonDomain

public struct ProviderRawReference: Codable, Sendable {
    public let kind: String
    public let offset: String?
    public let eventName: String?

    public init(kind: String, offset: String?, eventName: String?) {
        self.kind = kind
        self.offset = offset
        self.eventName = eventName
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case offset
        case eventName = "event_name"
    }
}

public enum ProviderSessionOriginHint: String, Codable, Sendable {
    case unknown
    case startedDuringLiveRuntime = "started_during_live_runtime"
}

public struct ProviderUsageSampleEvent: Codable, Sendable {
    public let eventType: String
    public let provider: ProviderCode
    public let sourceMode: String
    public let providerSessionID: String
    public let observedAt: String
    public let workspaceDir: String?
    public let modelSlug: String?
    public let transcriptPath: String?
    public let totalInputTokens: Int64
    public let totalOutputTokens: Int64
    public let totalCachedInputTokens: Int64
    public let normalizedTotalTokens: Int64
    public let providerEventFingerprint: String
    public let rawReference: ProviderRawReference
    public let currentInputTokens: Int64?
    public let currentOutputTokens: Int64?
    public let sessionOriginHint: ProviderSessionOriginHint

    public init(
        eventType: String,
        provider: ProviderCode,
        sourceMode: String,
        providerSessionID: String,
        observedAt: String,
        workspaceDir: String?,
        modelSlug: String?,
        transcriptPath: String?,
        totalInputTokens: Int64,
        totalOutputTokens: Int64,
        totalCachedInputTokens: Int64,
        normalizedTotalTokens: Int64,
        providerEventFingerprint: String,
        rawReference: ProviderRawReference,
        currentInputTokens: Int64?,
        currentOutputTokens: Int64?,
        sessionOriginHint: ProviderSessionOriginHint = .unknown
    ) {
        self.eventType = eventType
        self.provider = provider
        self.sourceMode = sourceMode
        self.providerSessionID = providerSessionID
        self.observedAt = observedAt
        self.workspaceDir = workspaceDir
        self.modelSlug = modelSlug
        self.transcriptPath = transcriptPath
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalCachedInputTokens = totalCachedInputTokens
        self.normalizedTotalTokens = normalizedTotalTokens
        self.providerEventFingerprint = providerEventFingerprint
        self.rawReference = rawReference
        self.currentInputTokens = currentInputTokens
        self.currentOutputTokens = currentOutputTokens
        self.sessionOriginHint = sessionOriginHint
    }

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case provider
        case sourceMode = "source_mode"
        case providerSessionID = "provider_session_id"
        case observedAt = "observed_at"
        case workspaceDir = "workspace_dir"
        case modelSlug = "model_slug"
        case transcriptPath = "transcript_path"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCachedInputTokens = "total_cached_input_tokens"
        case normalizedTotalTokens = "normalized_total_tokens"
        case providerEventFingerprint = "provider_event_fingerprint"
        case rawReference = "raw_reference"
        case currentInputTokens = "current_input_tokens"
        case currentOutputTokens = "current_output_tokens"
        case sessionOriginHint = "session_origin_hint"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(String.self, forKey: .eventType)
        provider = try container.decode(ProviderCode.self, forKey: .provider)
        sourceMode = try container.decode(String.self, forKey: .sourceMode)
        providerSessionID = try container.decode(String.self, forKey: .providerSessionID)
        observedAt = try container.decode(String.self, forKey: .observedAt)
        workspaceDir = try container.decodeIfPresent(String.self, forKey: .workspaceDir)
        modelSlug = try container.decodeIfPresent(String.self, forKey: .modelSlug)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        totalInputTokens = try container.decode(Int64.self, forKey: .totalInputTokens)
        totalOutputTokens = try container.decode(Int64.self, forKey: .totalOutputTokens)
        totalCachedInputTokens = try container.decode(Int64.self, forKey: .totalCachedInputTokens)
        normalizedTotalTokens = try container.decode(Int64.self, forKey: .normalizedTotalTokens)
        providerEventFingerprint = try container.decode(String.self, forKey: .providerEventFingerprint)
        rawReference = try container.decode(ProviderRawReference.self, forKey: .rawReference)
        currentInputTokens = try container.decodeIfPresent(Int64.self, forKey: .currentInputTokens)
        currentOutputTokens = try container.decodeIfPresent(Int64.self, forKey: .currentOutputTokens)
        sessionOriginHint = try container.decodeIfPresent(
            ProviderSessionOriginHint.self,
            forKey: .sessionOriginHint
        ) ?? .unknown
    }

    public func validate() throws {
        guard eventType == "provider_usage_sample" else {
            throw ProviderInboxValidationError.invalidEventType(eventType)
        }
        guard !sourceMode.isEmpty else {
            throw ProviderInboxValidationError.missingField("source_mode")
        }
        guard !providerSessionID.isEmpty else {
            throw ProviderInboxValidationError.missingField("provider_session_id")
        }
        guard !providerEventFingerprint.isEmpty else {
            throw ProviderInboxValidationError.missingField("provider_event_fingerprint")
        }
        guard totalInputTokens >= 0,
              totalOutputTokens >= 0,
              totalCachedInputTokens >= 0,
              normalizedTotalTokens >= 0 else {
            throw ProviderInboxValidationError.negativeTokenValue
        }
    }
}

public enum ProviderInboxValidationError: Error, LocalizedError {
    case invalidEventType(String)
    case missingField(String)
    case negativeTokenValue

    public var errorDescription: String? {
        switch self {
        case .invalidEventType(let value):
            return "invalid event_type: \(value)"
        case .missingField(let field):
            return "missing required field: \(field)"
        case .negativeTokenValue:
            return "token values must be non-negative"
        }
    }
}
