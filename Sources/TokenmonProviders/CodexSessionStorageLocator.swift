import Foundation

public struct CodexSessionStorageLocatorConfig: Sendable {
    public let configurationRootPath: String?
    public let environment: [String: String]
    public let homeDirectoryProvider: @Sendable () -> URL

    public init(
        configurationRootPath: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectoryProvider: @escaping @Sendable () -> URL = {
            FileManager.default.homeDirectoryForCurrentUser
        }
    ) {
        self.configurationRootPath = configurationRootPath
        self.environment = environment
        self.homeDirectoryProvider = homeDirectoryProvider
    }
}

public enum CodexSessionStorageLocator {
    public static func resolveTranscriptPath(
        sessionID: String,
        config: CodexSessionStorageLocatorConfig = CodexSessionStorageLocatorConfig()
    ) -> String? {
        let trimmedSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSessionID.isEmpty == false else {
            return nil
        }

        let sessionsRoot = URL(fileURLWithPath: sessionStorageRootPath(config: config), isDirectory: true)
        guard FileManager.default.fileExists(atPath: sessionsRoot.path) else {
            return nil
        }

        let expectedSuffix = "-\(trimmedSessionID).jsonl"
        let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var newestMatch: (path: String, modifiedAt: Date)?

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "jsonl",
                  fileURL.lastPathComponent.hasSuffix(expectedSuffix) else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile != false else {
                continue
            }

            let modifiedAt = values?.contentModificationDate ?? .distantPast
            if newestMatch == nil || modifiedAt > newestMatch?.modifiedAt ?? .distantPast {
                newestMatch = (fileURL.path, modifiedAt)
            }
        }

        return newestMatch?.path
    }

    public static func sessionStorageRootPath(
        config: CodexSessionStorageLocatorConfig = CodexSessionStorageLocatorConfig()
    ) -> String {
        let configurationRoot = resolvedConfigurationRootPath(config: config)
        return URL(fileURLWithPath: configurationRoot, isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
            .path
    }

    private static func resolvedConfigurationRootPath(config: CodexSessionStorageLocatorConfig) -> String {
        if let codexHome = config.environment["CODEX_HOME"]?.trimmedNonEmpty {
            return codexHome
        }

        if let configurationRootPath = config.configurationRootPath?.trimmedNonEmpty {
            return configurationRootPath
        }

        if let tokenmonHome = config.environment["TOKENMON_HOME_OVERRIDE"]?.trimmedNonEmpty {
            return URL(fileURLWithPath: tokenmonHome, isDirectory: true)
                .appendingPathComponent(".codex", isDirectory: true)
                .path
        }

        return config.homeDirectoryProvider()
            .appendingPathComponent(".codex", isDirectory: true)
            .path
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
