import Foundation
import Testing
import TokenmonProviders

struct ClaudeHookAdapterTests {
    @Test
    func decodesSessionStartPayloadWithModelAsString() throws {
        let json = """
        {
          "session_id": "feb44cf8-9ff5-4adf-a7a1-c4a8003e4081",
          "transcript_path": "/tmp/x.jsonl",
          "cwd": "/tmp",
          "hook_event_name": "SessionStart",
          "source": "startup",
          "model": "claude-opus-4-7[1m]"
        }
        """

        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))

        #expect(payload.sessionID == "feb44cf8-9ff5-4adf-a7a1-c4a8003e4081")
        #expect(payload.hookEventName == "SessionStart")
        #expect(payload.model?.id == "claude-opus-4-7[1m]")
        #expect(payload.model?.displayName == nil)
    }

    @Test
    func decodesStatusLineShapedPayloadWithModelAsObject() throws {
        let json = """
        {
          "session_id": "abc",
          "hook_event_name": "SessionStart",
          "model": {"id": "claude-opus-4-1", "display_name": "Opus"}
        }
        """

        let payload = try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))

        #expect(payload.model?.id == "claude-opus-4-1")
        #expect(payload.model?.displayName == "Opus")
    }

    @Test
    func importsSessionStartPayloadWithModelAsString() throws {
        let json = """
        {
          "session_id": "feb44cf8-9ff5-4adf-a7a1-c4a8003e4081",
          "transcript_path": "/tmp/x.jsonl",
          "cwd": "/tmp",
          "hook_event_name": "SessionStart",
          "source": "startup",
          "model": "claude-opus-4-7[1m]"
        }
        """

        let result = try ClaudeHookAdapter.importPayload(json: json)

        #expect(result.hookEventName == "SessionStart")
        #expect(result.sessionID == "feb44cf8-9ff5-4adf-a7a1-c4a8003e4081")
    }
}
