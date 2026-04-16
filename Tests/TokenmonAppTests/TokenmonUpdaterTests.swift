import Foundation
import Testing
@testable import TokenmonApp

struct TokenmonUpdaterTests {
    @Test
    func updaterAvailabilityRequiresFeedURLAndPublicKey() {
        let unavailableForMissingFeed = TokenmonAppUpdaterAvailability.Configuration.resolve(
            infoDictionary: [
                "SUPublicEDKey": "public-key",
            ]
        )
        #expect(unavailableForMissingFeed == .unavailable(.missingFeedURL))

        let unavailableForInvalidFeed = TokenmonAppUpdaterAvailability.Configuration.resolve(
            infoDictionary: [
                "SUFeedURL": "::not-a-url::",
                "SUPublicEDKey": "public-key",
            ]
        )
        #expect(unavailableForInvalidFeed == .unavailable(.invalidFeedURL))

        let unavailableForMissingKey = TokenmonAppUpdaterAvailability.Configuration.resolve(
            infoDictionary: [
                "SUFeedURL": "https://example.com/appcast.xml",
            ]
        )
        #expect(unavailableForMissingKey == .unavailable(.missingPublicKey))
    }

    @Test
    func updaterAvailabilityAcceptsConfiguredBundleMetadata() {
        let availability = TokenmonAppUpdaterAvailability.Configuration.resolve(
            infoDictionary: [
                "SUFeedURL": "https://example.com/appcast.xml",
                "SUPublicEDKey": "public-key",
            ]
        )

        #expect(
            availability == .available(
                TokenmonAppUpdaterAvailability.Configuration(
                    feedURL: URL(string: "https://example.com/appcast.xml")!,
                    publicEDKey: "public-key"
                )
            )
        )
    }

    @Test
    func updaterDiagnosticsAcceptLocalOverrideWithoutBundleMetadata() throws {
        let dbPath = temporaryDatabasePath()
        try TokenmonAppUpdaterOverrideStore.save(
            TokenmonAppUpdaterOverride(
                feedURL: "https://example.com/staging-appcast.xml",
                publicEDKey: "override-public-key"
            ),
            databasePath: dbPath
        )

        let diagnostics = TokenmonAppUpdaterDiagnosticsSnapshot.resolve(
            infoDictionary: [:],
            databasePath: dbPath
        )

        #expect(
            diagnostics.availability == .available(
                TokenmonAppUpdaterAvailability.Configuration(
                    feedURL: URL(string: "https://example.com/staging-appcast.xml")!,
                    publicEDKey: "override-public-key"
                )
            )
        )
        #expect(diagnostics.feedURLSource == .localOverrideFile)
        #expect(diagnostics.publicEDKeySource == .localOverrideFile)
        #expect(diagnostics.hasNonBundledConfiguration)
    }

    @Test
    func updaterDiagnosticsMergeBundleMetadataWithLocalFeedOverride() throws {
        let dbPath = temporaryDatabasePath()
        try TokenmonAppUpdaterOverrideStore.save(
            TokenmonAppUpdaterOverride(feedURL: "https://example.com/staging-appcast.xml"),
            databasePath: dbPath
        )

        let diagnostics = TokenmonAppUpdaterDiagnosticsSnapshot.resolve(
            infoDictionary: [
                "SUFeedURL": "https://example.com/appcast.xml",
                "SUPublicEDKey": "bundle-public-key",
            ],
            databasePath: dbPath
        )

        #expect(
            diagnostics.availability == .available(
                TokenmonAppUpdaterAvailability.Configuration(
                    feedURL: URL(string: "https://example.com/staging-appcast.xml")!,
                    publicEDKey: "bundle-public-key"
                )
            )
        )
        #expect(diagnostics.feedURLSource == .localOverrideFile)
        #expect(diagnostics.publicEDKeySource == .bundleMetadata)
    }

    @Test
    func updaterDiagnosticsFailClosedForMalformedLocalOverrideFile() throws {
        let dbPath = temporaryDatabasePath()
        let overrideFilePath = TokenmonAppUpdaterOverrideStore.filePath(databasePath: dbPath)
        let overrideDirectory = URL(fileURLWithPath: overrideFilePath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: overrideDirectory, withIntermediateDirectories: true)
        try Data("{not json}".utf8).write(to: URL(fileURLWithPath: overrideFilePath), options: .atomic)

        let diagnostics = TokenmonAppUpdaterDiagnosticsSnapshot.resolve(
            infoDictionary: [
                "SUFeedURL": "https://example.com/appcast.xml",
                "SUPublicEDKey": "bundle-public-key",
            ],
            databasePath: dbPath
        )

        #expect(diagnostics.unavailabilityReason == .invalidOverrideFile)
        #expect(diagnostics.overrideFileExists)
        #expect(diagnostics.overrideLoadErrorDescription != nil)
    }

    @Test
    @MainActor
    func updaterAnalyticsBridgeCapturesLifecycleStages() {
        let tracker = TokenmonAnalyticsTrackerSpy()
        let bridge = TokenmonAppUpdaterAnalyticsBridge(
            analyticsTracker: tracker,
            feedSourceProvider: { "bundle_metadata" }
        )

        bridge.beginUpdateCheck(.updates)
        bridge.captureUpdateAvailable(version: "0.1.4")
        bridge.captureDownloadCompleted(version: "0.1.4")
        bridge.captureInstallRequested(version: "0.1.4")
        bridge.setManualUpdateCheckInProgress(false)
        bridge.beginUpdateCheck(.updatesInBackground)
        bridge.captureNoUpdateFound()

        let updateEvents = tracker.events(named: "tokenmon_update_state_changed")
        #expect(updateEvents.map { $0.properties["stage"] } == [
            "check_requested",
            "available",
            "downloaded",
            "install_requested",
            "check_requested",
            "not_available",
        ])
        #expect(updateEvents.first?.properties["manual_triggered"] == "true")
        #expect(updateEvents[1].properties["available_version"] == "0.1.4")
        #expect(updateEvents[1].properties["feed_source"] == "bundle_metadata")
        #expect(updateEvents.last?.properties["manual_triggered"] == "false")
    }

    private func temporaryDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenmonUpdaterTests-\(UUID().uuidString)", isDirectory: true)
        return directory.appendingPathComponent("tokenmon.sqlite").path
    }
}
