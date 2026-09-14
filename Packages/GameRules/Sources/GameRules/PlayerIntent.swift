/// 아직 EntityID로 해석되지 않은 플레이어의 의도 (원본 설계 §12).
/// `ParsedIntent`(AI 계층 Generable DTO, 보강판 §30)는 순수 함수로 이 타입으로 변환된다.
/// `KeywordIntentParser`(GameAI)는 이 타입을 직접 만든다.
public enum IntentKind: String, Sendable, Equatable, Codable {
    case move
    case look
    case talk
    case attack
    case take
    case use
    case unknown
}

public struct PlayerIntent: Sendable, Equatable {
    public let kind: IntentKind
    /// 플레이어가 대상을 가리킨 원문 그대로. 대상이 없으면 빈 문자열.
    public let target: String
    /// `talk`에서만 의미가 있다. 그 외에는 빈 문자열.
    public let speech: String

    public init(kind: IntentKind, target: String = "", speech: String = "") {
        self.kind = kind
        self.target = target
        self.speech = speech
    }
}
