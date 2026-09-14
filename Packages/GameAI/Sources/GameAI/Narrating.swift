import GameCore

/// Narrating 구현체가 서사를 쓰는 데 필요한 전부. 상태 접근 권한을 주지 않는다 —
/// 엔진이 이미 확정한 이벤트와 이름표만 넘긴다(§36 "엔진이 권위를 독점한다").
public struct NarrationContext: Sendable {
    public let playerID: EntityID
    public let locationName: String
    /// 이번 턴에 실제로 일어난 사건. `.rolled`는 호출부가 넣더라도 narrator가 걸러낸다
    /// (수정 지침 C — 주사위 눈은 LLM에게 보여줄 이유가 없다).
    public let recentEvents: [GameEvent]
    /// 사건 속 EntityID를 사람이 읽을 이름으로 바꾸기 위한 표. 없는 ID는 narrator가
    /// 알아서 대명사로 대체한다.
    public let entityNames: [EntityID: String]

    public init(playerID: EntityID, locationName: String, recentEvents: [GameEvent], entityNames: [EntityID: String]) {
        self.playerID = playerID
        self.locationName = locationName
        self.recentEvents = recentEvents
        self.entityNames = entityNames
    }
}

/// GameEvent를 산문으로 바꾼다 (설계 §29). `GameCore`를 직접 바꿀 권한은 없다 —
/// 읽고 이야기할 뿐이다.
public protocol Narrating: Sendable {
    func narrate(_ context: NarrationContext) async throws -> String
}
