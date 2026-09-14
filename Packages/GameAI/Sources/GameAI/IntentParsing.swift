import GameCore
import GameRules

/// 입력을 해석할 때 참고할 수 있는 것 — 가시성 화이트리스트뿐이다.
/// 구현체가 여기서 EntityID를 직접 다룰 필요는 없다(그건 ActionResolver의 몫).
public struct IntentContext: Sendable {
    public let visibleEntities: [EntityID: String]

    public init(visibleEntities: [EntityID: String]) {
        self.visibleEntities = visibleEntities
    }
}

/// 자연어(또는 정형 키워드) 입력을 `PlayerIntent`로 바꾼다 (설계 §29).
/// Foundation Models는 로딩에 수 초가 걸리고 시뮬레이터/CI에서 동작을 보장할 수
/// 없으므로, 이 경계가 없으면 게임 로직을 한 턴도 자동 테스트할 수 없다.
public protocol IntentParsing: Sendable {
    func parse(input: String, context: IntentContext) async throws -> PlayerIntent
}
