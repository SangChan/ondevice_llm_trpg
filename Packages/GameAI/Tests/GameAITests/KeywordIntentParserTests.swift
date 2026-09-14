import Testing
import GameRules
@testable import GameAI

@Suite("KeywordIntentParser")
struct KeywordIntentParserTests {
    let parser = KeywordIntentParser()
    let emptyContext = IntentContext(visibleEntities: [:])

    @Test("recognizes each verb category and captures the target")
    func recognizesEachVerbCategory() async throws {
        #expect(try await parser.parse(input: "go to the cave", context: emptyContext) == PlayerIntent(kind: .move, target: "the cave"))
        #expect(try await parser.parse(input: "look", context: emptyContext) == PlayerIntent(kind: .look))
        #expect(try await parser.parse(input: "look around", context: emptyContext) == PlayerIntent(kind: .look))
        #expect(try await parser.parse(input: "talk to the hunter", context: emptyContext) == PlayerIntent(kind: .talk, target: "the hunter"))
        #expect(try await parser.parse(input: "attack the goblin", context: emptyContext) == PlayerIntent(kind: .attack, target: "the goblin"))
        #expect(try await parser.parse(input: "take the sword", context: emptyContext) == PlayerIntent(kind: .take, target: "the sword"))
        #expect(try await parser.parse(input: "use the potion", context: emptyContext) == PlayerIntent(kind: .use, target: "the potion"))
    }

    @Test("longer verb phrases win over shorter prefixes")
    func longerVerbPhraseWinsOverShorterPrefix() async throws {
        // "go" 가 먼저 매칭되면 target이 "to the cave"가 되어버린다 — "go to"가 이겨야 한다.
        let intent = try await parser.parse(input: "go to the cave", context: emptyContext)
        #expect(intent.target == "the cave")
    }

    @Test("unrecognized input is unknown, with the raw text preserved")
    func unrecognizedInputIsUnknown() async throws {
        let intent = try await parser.parse(input: "juggle three torches", context: emptyContext)
        #expect(intent == PlayerIntent(kind: .unknown, target: "juggle three torches"))
    }

    @Test("empty input is unknown with no target")
    func emptyInputIsUnknown() async throws {
        let intent = try await parser.parse(input: "   ", context: emptyContext)
        #expect(intent == PlayerIntent(kind: .unknown))
    }
}
