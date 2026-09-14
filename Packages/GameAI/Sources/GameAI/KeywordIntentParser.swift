import GameRules

/// LLM 호출 없는 정형 입력 fast path (설계 §29). AI Mode에서는 `ChainedIntentParser`의
/// `fast` 후보로(§29, Phase 3), Classic Mode에서는 단독으로 쓰인다.
/// 대상 문자열을 실제 EntityID로 바꾸는 일은 하지 않는다 — 그건 `ActionResolver`의 몫이다.
public struct KeywordIntentParser: IntentParsing {
    public init() {}

    public func parse(input: String, context: IntentContext) async throws -> PlayerIntent {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return PlayerIntent(kind: .unknown) }

        let lower = trimmed.lowercased()

        if Self.strip(lower, verbs: Self.lookVerbs) != nil {
            return PlayerIntent(kind: .look)
        }
        if let rest = Self.strip(lower, verbs: Self.moveVerbs) {
            return PlayerIntent(kind: .move, target: rest)
        }
        if let rest = Self.strip(lower, verbs: Self.talkVerbs) {
            return PlayerIntent(kind: .talk, target: rest)
        }
        if let rest = Self.strip(lower, verbs: Self.attackVerbs) {
            return PlayerIntent(kind: .attack, target: rest)
        }
        if let rest = Self.strip(lower, verbs: Self.takeVerbs) {
            return PlayerIntent(kind: .take, target: rest)
        }
        if let rest = Self.strip(lower, verbs: Self.useVerbs) {
            return PlayerIntent(kind: .use, target: rest)
        }

        return PlayerIntent(kind: .unknown, target: trimmed)
    }

    private static let moveVerbs = ["go to", "go", "move to", "move", "walk to", "walk", "head to", "head", "enter"]
    private static let lookVerbs = ["look around", "look", "observe", "examine surroundings"]
    private static let talkVerbs = ["talk to", "talk with", "talk", "speak to", "speak with", "speak", "ask"]
    private static let attackVerbs = ["attack", "fight", "hit", "kill", "strike"]
    private static let takeVerbs = ["take", "grab", "pick up", "get"]
    private static let useVerbs = ["use", "drink", "eat", "consume"]

    /// 가장 긴 동사구부터 매칭한다("go to" > "go") — 짧은 동사가 먼저 걸려 목적어를
    /// 잘라먹지 않도록.
    private static func strip(_ text: String, verbs: [String]) -> String? {
        for verb in verbs.sorted(by: { $0.count > $1.count }) {
            if text == verb {
                return ""
            }
            if text.hasPrefix(verb + " ") {
                return String(text.dropFirst(verb.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
