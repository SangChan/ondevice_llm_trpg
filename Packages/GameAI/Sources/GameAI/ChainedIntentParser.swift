import GameRules

/// 정형 입력은 LLM 없이 빠르게, 나머지는 LLM으로 (설계 §29). AI Mode에서만 쓰인다 —
/// Classic Mode는 fallback이 없으므로 `KeywordIntentParser`를 단독으로 쓴다.
public struct ChainedIntentParser: IntentParsing {
    public let fast: any IntentParsing
    public let fallback: any IntentParsing
    private let timeoutSeconds: Double

    /// `ResilientNarrator`와 같은 이유로 타임아웃을 둔다(`AITimeout.swift` 참고) —
    /// fast 경로는 LLM이 없어 순간적이므로 여기 걸지 않는다.
    public init(fast: any IntentParsing, fallback: any IntentParsing, timeoutSeconds: Double = 8) {
        self.fast = fast
        self.fallback = fallback
        self.timeoutSeconds = timeoutSeconds
    }

    public func parse(input: String, context: IntentContext) async throws -> PlayerIntent {
        let intent = try await fast.parse(input: input, context: context)
        guard intent.kind == .unknown else { return intent }

        return try await withAITimeout(seconds: timeoutSeconds) {
            try await fallback.parse(input: input, context: context)
        }
    }
}
