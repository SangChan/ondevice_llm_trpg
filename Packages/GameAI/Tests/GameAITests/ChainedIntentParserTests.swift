import Testing
import GameRules
@testable import GameAI

private struct StubIntentParser: IntentParsing {
    let result: PlayerIntent
    var hangs = false

    func parse(input: String, context: IntentContext) async throws -> PlayerIntent {
        if hangs {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        }
        return result
    }
}

@Suite("ChainedIntentParser")
struct ChainedIntentParserTests {
    let emptyContext = IntentContext(visibleEntities: [:])

    @Test("a resolved fast intent is returned without consulting the fallback")
    func resolvedFastIntentSkipsFallback() async throws {
        let fast = StubIntentParser(result: PlayerIntent(kind: .look))
        let fallback = StubIntentParser(result: PlayerIntent(kind: .attack, target: "should not be used"))
        let chained = ChainedIntentParser(fast: fast, fallback: fallback)

        let intent = try await chained.parse(input: "look", context: emptyContext)

        #expect(intent == PlayerIntent(kind: .look))
    }

    @Test("an unknown fast intent falls through to the fallback parser")
    func unknownFastIntentUsesFallback() async throws {
        let fast = StubIntentParser(result: PlayerIntent(kind: .unknown, target: "juggle torches"))
        let fallback = StubIntentParser(result: PlayerIntent(kind: .attack, target: "goblin"))
        let chained = ChainedIntentParser(fast: fast, fallback: fallback)

        let intent = try await chained.parse(input: "juggle torches", context: emptyContext)

        #expect(intent == PlayerIntent(kind: .attack, target: "goblin"))
    }

    @Test("a fallback that hangs past the timeout throws instead of blocking forever")
    func hangingFallbackTimesOut() async throws {
        let fast = StubIntentParser(result: PlayerIntent(kind: .unknown, target: "juggle torches"))
        let fallback = StubIntentParser(result: PlayerIntent(kind: .attack, target: "goblin"), hangs: true)
        let chained = ChainedIntentParser(fast: fast, fallback: fallback, timeoutSeconds: 0.05)

        await #expect(throws: AITimeoutError.self) {
            try await chained.parse(input: "juggle torches", context: emptyContext)
        }
    }
}
