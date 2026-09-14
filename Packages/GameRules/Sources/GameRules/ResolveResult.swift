import GameCore

/// PlayerIntent를 GameAction으로 바꾸는 시도의 결과 (수정 지침 §13-D).
/// 세 실패 경우 모두 GameEngine을 호출하지 않는다 — Resolver 실패와 Engine 실패는
/// 다른 계층의 사건이며, 섞으면 턴 계산이 망가진다.
public enum ResolveResult: Sendable, Equatable {
    case resolved(GameAction)
    /// 게임 턴을 소비하지 않고 DM이 되묻는다.
    case ambiguous(candidates: [EntityID])
    /// 턴을 소비하지 않고 "there is nothing like that here" 계열로 응답한다.
    case notFound(term: String)
    /// MVP가 지원하지 않는 행동(`.unknown` intent 포함).
    case unsupported
}
