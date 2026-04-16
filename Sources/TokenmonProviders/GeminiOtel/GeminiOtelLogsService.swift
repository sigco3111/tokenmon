import Foundation
import GRPC
import NIOCore
import TokenmonDomain

/// Receives OTLP Logs and converts every `gemini_cli.api_response` event into
/// a ProviderUsageSampleEvent line in the Gemini inbox file. Trace data goes
/// to a separate accept-and-discard service.
public final class GeminiOtelLogsService {
    private let writer: GeminiOtelInboxWriter
    private let tracker: GeminiCumulativeTracker

    public init(writer: GeminiOtelInboxWriter, tracker: GeminiCumulativeTracker) {
        self.writer = writer
        self.tracker = tracker
    }

    /// Test seam: handles a request as if it had been delivered over gRPC.
    /// Production code goes through the generated `Provider` protocol method.
    public func handleExportRequestForTesting(
        _ request: Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest
    ) throws {
        try processRequest(request)
    }

    fileprivate func processRequest(
        _ request: Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest
    ) throws {
        for resourceLogs in request.resourceLogs {
            for scopeLogs in resourceLogs.scopeLogs {
                for record in scopeLogs.logRecords {
                    guard let event = Self.extractApiResponseEvent(from: record) else {
                        continue
                    }
                    let totals = tracker.recordEvent(
                        sessionID: event.sessionID,
                        inputTokens: event.inputTokens,
                        outputTokens: event.outputTokens,
                        cachedContentTokens: event.cachedContentTokens,
                        totalTokens: event.totalTokens
                    )
                    try writer.append(
                        event: event,
                        cumulativeInputTokens: totals.totalInputTokens,
                        cumulativeOutputTokens: totals.totalOutputTokens,
                        cumulativeCachedInputTokens: totals.totalCachedInputTokens,
                        cumulativeNormalizedTotalTokens: totals.normalizedTotalTokens
                    )
                }
            }
        }
    }

    private static func extractApiResponseEvent(
        from record: Opentelemetry_Proto_Logs_V1_LogRecord
    ) -> GeminiSampleEvent? {
        var attributes: [String: Opentelemetry_Proto_Common_V1_AnyValue] = [:]
        for kv in record.attributes {
            attributes[kv.key] = kv.value
        }

        guard case .stringValue(let eventName) = attributes["event.name"]?.value,
              eventName == "gemini_cli.api_response" else {
            return nil
        }

        guard case .stringValue(let sessionID) = attributes["session.id"]?.value else {
            return nil
        }

        let model = Self.string(attributes["model"]) ?? "unknown"
        let inputTokens = Self.int(attributes["input_token_count"]) ?? 0
        let outputTokens = Self.int(attributes["output_token_count"]) ?? 0
        let cached = Self.int(attributes["cached_content_token_count"]) ?? 0
        let thoughts = Self.int(attributes["thoughts_token_count"]) ?? 0
        let tool = Self.int(attributes["tool_token_count"]) ?? 0
        let total = Self.int(attributes["total_token_count"]) ?? (inputTokens + outputTokens)
        let duration = Self.int(attributes["duration_ms"]) ?? 0

        let observedAt: Date
        if record.timeUnixNano > 0 {
            observedAt = Date(timeIntervalSince1970: TimeInterval(record.timeUnixNano) / 1_000_000_000)
        } else {
            observedAt = Date()
        }

        return GeminiSampleEvent(
            sessionID: sessionID,
            observedAt: observedAt,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cachedContentTokens: cached,
            thoughtsTokens: thoughts,
            toolTokens: tool,
            totalTokens: total,
            durationMs: duration
        )
    }

    private static func string(_ value: Opentelemetry_Proto_Common_V1_AnyValue?) -> String? {
        guard case .stringValue(let s) = value?.value else { return nil }
        return s
    }

    private static func int(_ value: Opentelemetry_Proto_Common_V1_AnyValue?) -> Int64? {
        guard let value else { return nil }
        switch value.value {
        case .intValue(let i): return i
        case .doubleValue(let d): return Int64(d)
        default: return nil
        }
    }
}

extension GeminiOtelLogsService: Opentelemetry_Proto_Collector_Logs_V1_LogsServiceProvider {
    public var interceptors: Opentelemetry_Proto_Collector_Logs_V1_LogsServiceServerInterceptorFactoryProtocol? {
        nil
    }

    public func export(
        request: Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest,
        context: StatusOnlyCallContext
    ) -> EventLoopFuture<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse> {
        do {
            try processRequest(request)
            return context.eventLoop.makeSucceededFuture(
                Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse()
            )
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }
}
