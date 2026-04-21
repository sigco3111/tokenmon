import Foundation
import Testing
import TokenmonDomain
import TokenmonProviders

struct OpenCodeAdapterTests {
    private func fixtureDBPath() -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repoRoot
            .appendingPathComponent("Fixtures/OpenCodeMessages/sample-opencode.db")
            .path
    }

    @Test
    func readsAllAssistantMessagesFromFixtureDB() throws {
        let events = try OpenCodeSQLiteAdapter.providerEvents(from: fixtureDBPath())

        // 8 messages total, 2 are user-role → 6 assistant events
        #expect(events.count == 6)

        let session1Events = events.filter { $0.providerSessionID == "sess-001" }
        let session2Events = events.filter { $0.providerSessionID == "sess-002" }
        #expect(session1Events.count == 4)
        #expect(session2Events.count == 2)
    }

    @Test
    func computesCumulativeTotalsPerSession() throws {
        let events = try OpenCodeSQLiteAdapter.providerEvents(from: fixtureDBPath())

        let session1Events = events.filter { $0.providerSessionID == "sess-001" }

        // msg-001: 962+142+5184+0 = 6288
        #expect(session1Events[0].normalizedTotalTokens == 6288)
        #expect(session1Events[0].currentInputTokens == 962)
        #expect(session1Events[0].currentOutputTokens == 142)

        // msg-003: 2400+876+12000+2000 = 17276, cumulative = 6288+17276 = 23564
        #expect(session1Events[1].normalizedTotalTokens == 23564)

        // msg-004: 500+80+3000+0 = 3580, cumulative = 23564+3580 = 27144
        #expect(session1Events[2].normalizedTotalTokens == 27144)

        // msg-005: 1500+450+8000+500 = 10450, cumulative = 27144+10450 = 37594
        #expect(session1Events[3].normalizedTotalTokens == 37594)

        let session2Events = events.filter { $0.providerSessionID == "sess-002" }

        // msg-006: 1800+320+9000+1000 = 12120
        #expect(session2Events[0].normalizedTotalTokens == 12120)

        // msg-008: 3200+1100+15000+3000 = 22300, cumulative = 12120+22300 = 34420
        #expect(session2Events[1].normalizedTotalTokens == 34420)
    }

    @Test
    func includesCacheTokensInCachedInputTotal() throws {
        let events = try OpenCodeSQLiteAdapter.providerEvents(from: fixtureDBPath())

        // msg-001: cacheRead=5184, cacheWrite=0 → cachedInput = 5184
        let first = events.first!
        #expect(first.totalCachedInputTokens == 5184)

        // msg-003: cacheRead=12000, cacheWrite=2000 → cachedInput = 14000
        let second = events.filter { $0.providerSessionID == "sess-001" }[1]
        #expect(second.totalCachedInputTokens == 14000)
    }

    @Test
    func producesCorrectFingerprintFormat() throws {
        let events = try OpenCodeSQLiteAdapter.providerEvents(from: fixtureDBPath())
        let first = events.first!

        #expect(first.providerEventFingerprint.hasPrefix("opencode:sess-001:"))
        // SHA-256 produces 64 hex characters after the prefix
        let hexPart = first.providerEventFingerprint
            .replacingOccurrences(of: "opencode:sess-001:", with: "")
        #expect(hexPart.count == 64)
        #expect(hexPart.allSatisfy { $0.isHexDigit })
    }

    @Test
    func setsProviderAndSourceModeFields() throws {
        let events = try OpenCodeSQLiteAdapter.providerEvents(from: fixtureDBPath())
        let first = events.first!

        #expect(first.provider == ProviderCode.opencode)
        #expect(first.sourceMode == "opencode_sqlite_backfill")
        #expect(first.rawReference.kind == "opencode_sqlite_message")
        #expect(first.rawReference.offset == "msg-001")
        #expect(first.rawReference.eventName == "message")
    }

    @Test
    func observesWorkspaceDirAndModelSlug() throws {
        let events = try OpenCodeSQLiteAdapter.providerEvents(from: fixtureDBPath())
        let first = events.first!

        #expect(first.workspaceDir != nil)
        #expect(first.modelSlug != nil)
    }

    @Test
    func filtersBySinceMessageID() throws {
        let events = try OpenCodeSQLiteAdapter.providerEvents(
            from: fixtureDBPath(),
            since: "msg-003"
        )

        // Messages with id > "msg-003": msg-004, msg-005, msg-006, msg-007, msg-008
        // Assistant only: msg-004, msg-005, msg-006, msg-008 = 4
        #expect(events.count == 4)

        // Cumulative totals are computed from the fetched subset, not the full session
        let session1Events = events.filter { $0.providerSessionID == "sess-001" }

        // msg-004: 500+80+3000+0 = 3580, cumulative = 3580
        #expect(session1Events[0].normalizedTotalTokens == 3580)

        // msg-005: 1500+450+8000+500 = 10450, cumulative = 3580+10450 = 14030
        #expect(session1Events[1].normalizedTotalTokens == 14030)
    }

    @Test
    func throwsDatabaseNotFoundForMissingPath() {
        #expect(throws: OpenCodeSQLiteAdapterError.self) {
            try OpenCodeSQLiteAdapter.providerEvents(from: "/nonexistent/opencode.db")
        }
    }

    @Test
    func returnsEmptyArrayForEmptySince() throws {
        // Passing nil (via the convenience overload) should return all events
        let events = try OpenCodeSQLiteAdapter.providerEvents(from: fixtureDBPath())
        #expect(events.count == 6)
    }
}
