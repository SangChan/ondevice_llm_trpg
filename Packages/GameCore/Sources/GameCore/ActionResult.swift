/// 구조화된 실패 사유. 문자열 비교를 강요하지 않고, 로컬라이즈 가능하며,
/// LLM에게 넘길 수 있는 사유가 된다 (수정 지침 B).
public enum ActionFailure: String, Codable, Sendable, Equatable {
    case actorNotFound
    case targetNotFound
    case targetNotHere
    case targetAlreadyDead
    case noConnection
    case itemNotHere
    case itemNotInInventory
    case itemNotUsable
}

public enum ActionOutcome: Sendable, Equatable, Codable {
    case success
    case failure(ActionFailure)
}

public struct ActionResult: Sendable, Equatable, Codable {
    public let outcome: ActionOutcome
    public let events: [GameEvent]

    public init(outcome: ActionOutcome, events: [GameEvent]) {
        self.outcome = outcome
        self.events = events
    }
}
