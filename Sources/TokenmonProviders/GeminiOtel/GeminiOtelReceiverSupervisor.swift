import Foundation
import Combine
import TokenmonDomain

/// A dependency interface that supplies the supervisor with the data it needs
/// from the persistence layer without creating a circular dependency between
/// `TokenmonProviders` and `TokenmonPersistence`.
public protocol GeminiOtelReceiverDataSource: AnyObject {
    /// Returns the per-session cumulative totals used to seed the tracker on
    /// startup so that a process restart does not produce a downward token jump.
    func latestGeminiSessionTotals() throws -> [String: GeminiSessionRunningTotals]
}

@MainActor
public final class GeminiOtelReceiverSupervisor: ObservableObject {
    public enum State: Equatable {
        case stopped
        case starting
        case running(host: String, port: Int)
        case failed(message: String)
    }

    @Published public private(set) var state: State = .stopped

    private let dataSource: GeminiOtelReceiverDataSource
    private let inboxPath: String
    private var server: GeminiOtelGrpcServer?

    public init(
        dataSource: GeminiOtelReceiverDataSource,
        inboxPath: String
    ) {
        self.dataSource = dataSource
        self.inboxPath = inboxPath
    }

    public func start() async {
        guard server == nil else {
            return
        }
        state = .starting

        let writer = GeminiOtelInboxWriter(inboxPath: inboxPath)
        let seed: [String: GeminiSessionRunningTotals]
        do {
            seed = try dataSource.latestGeminiSessionTotals()
        } catch {
            state = .failed(message: "Could not seed gemini session totals: \(error.localizedDescription)")
            return
        }
        let tracker = GeminiCumulativeTracker(seed: seed)
        let logs = GeminiOtelLogsService(writer: writer, tracker: tracker)
        let trace = GeminiOtelTraceService()
        let server = GeminiOtelGrpcServer(logsService: logs, traceService: trace)

        do {
            try await server.start()
            self.server = server
            state = .running(
                host: GeminiOtelGrpcServer.Configuration.default.host,
                port: GeminiOtelGrpcServer.Configuration.default.port
            )
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func stop() async {
        guard let server else {
            return
        }
        // Capture in a local constant so the MainActor-isolated property is not
        // accessed across the suspension point, satisfying Swift 6 data-race checks.
        let serverToStop = server
        do {
            try await serverToStop.stop()
            self.server = nil
            state = .stopped
        } catch {
            state = .failed(message: "Could not stop gemini receiver: \(error.localizedDescription)")
        }
    }
}
