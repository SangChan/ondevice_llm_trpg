import Testing
@testable import GameAI

@Suite("FoundationModelsIntentParser.convert")
struct FoundationModelsIntentParserTests {
    // 세션이 필요한 parse(input:context:)는 실기기 하니스 몫이다(설계 §37) — 여기서는
    // ParsedIntent(AI DTO) → PlayerIntent(도메인 타입) 순수 변환만 검증한다(§30).

    @Test("each generated kind maps to the matching domain intent kind")
    func eachKindMapsToDomainKind() {
        for kind in [GeneratedIntentKind.move, .look, .talk, .attack, .take, .use, .unknown] {
            let parsed = ParsedIntent(kind: kind, target: "x", speech: "y")
            let intent = FoundationModelsIntentParser.convert(parsed)
            #expect(intent.kind.rawValue == kind.rawValue)
        }
    }

    @Test("target and speech pass through unchanged")
    func targetAndSpeechPassThrough() {
        let parsed = ParsedIntent(kind: .talk, target: "the old hunter", speech: "Who are you?")
        let intent = FoundationModelsIntentParser.convert(parsed)
        #expect(intent.target == "the old hunter")
        #expect(intent.speech == "Who are you?")
    }
}
