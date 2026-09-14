/// 실제로 일어난 사건. Action이 "무엇을 하라"라면 Event는 "실제로 무엇이 일어났는가"다
/// (원본 설계 §6, 수정 지침 B·C).
public enum GameEvent: Sendable, Equatable, Codable {
    case moved(actor: EntityID, from: EntityID, to: EntityID)
    case observed(actor: EntityID, location: EntityID)
    case talked(actor: EntityID, target: EntityID, message: String)
    case attackHit(attacker: EntityID, target: EntityID, damage: Int)
    case attackMissed(attacker: EntityID, target: EntityID)
    case entityDied(entity: EntityID)
    case itemTaken(actor: EntityID, item: EntityID)
    case itemUsed(actor: EntityID, item: EntityID, target: EntityID?)
    /// 실패도 서사의 일부이므로 이벤트로 승격한다 — 엔진이 문장을 하드코딩하지 않는다
    /// (수정 지침 B).
    case actionRejected(reason: ActionFailure)
    /// 주사위 눈의 감사 로그. ContextBuilder에서는 반드시 제외한다 — LLM에게
    /// 눈을 보여줄 이유가 없고 토큰만 먹는다 (수정 지침 C).
    case rolled(kind: RollKind, sides: Int, result: Int)
}
