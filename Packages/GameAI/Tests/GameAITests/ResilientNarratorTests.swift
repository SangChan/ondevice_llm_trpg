import Testing
import GameCore
@testable import GameAI

private struct StubNarrator: Narrating {
    enum Behavior {
        case succeed(String)
        case fail
        case hang
    }
    let behavior: Behavior

    func narrate(_ context: NarrationContext) async throws -> String {
        switch behavior {
        case .succeed(let text): return text
        case .fail: throw StubError.forced
        case .hang:
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            return "should never reach here"
        }
    }
}

private enum StubError: Error { case forced }

@Suite("ResilientNarrator")
struct ResilientNarratorTests {
    private func context() -> NarrationContext {
        NarrationContext(playerID: EntityID(), locationName: "Dark Cave", recentEvents: [], entityNames: [:])
    }

    @Test("a succeeding primary is used as-is")
    func succeedingPrimaryIsUsed() async throws {
        let narrator = ResilientNarrator(primary: StubNarrator(behavior: .succeed("primary text")), fallback: StubNarrator(behavior: .succeed("fallback text")))
        let text = try await narrator.narrate(context())
        #expect(text == "primary text")
    }

    @Test("a failing primary falls back silently — the error never surfaces")
    func failingPrimaryFallsBackSilently() async throws {
        let narrator = ResilientNarrator(primary: StubNarrator(behavior: .fail), fallback: StubNarrator(behavior: .succeed("fallback text")))
        let text = try await narrator.narrate(context())
        #expect(text == "fallback text")
    }

    @Test("a primary that hangs past the timeout falls back instead of blocking forever")
    func hangingPrimaryTimesOutAndFallsBack() async throws {
        // 실기기에서 재현된 문제: availability가 .available이어도 응답이 멈출 수 있다
        // (AITimeout.swift 참고). 짧은 타임아웃으로 그 상황을 흉내 낸다.
        let narrator = ResilientNarrator(
            primary: StubNarrator(behavior: .hang),
            fallback: StubNarrator(behavior: .succeed("fallback text")),
            timeoutSeconds: 0.05
        )
        let text = try await narrator.narrate(context())
        #expect(text == "fallback text")
    }
}
