/// 게임 세계의 authoritative state (원본 설계 §4, 수정 지침 A-3).
public struct GameState: Codable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let seed: UInt64

    public var turn: Int
    public var player: Player

    public var locations: [EntityID: Location]
    public var npcs: [EntityID: NPC]
    public var items: [EntityID: Item]

    public init(
        seed: UInt64,
        player: Player,
        locations: [EntityID: Location] = [:],
        npcs: [EntityID: NPC] = [:],
        items: [EntityID: Item] = [:],
        turn: Int = 0,
        schemaVersion: Int = GameState.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.seed = seed
        self.turn = turn
        self.player = player
        self.locations = locations
        self.npcs = npcs
        self.items = items
    }
}

extension GameState {
    /// `owner`가 소지한 아이템. 결정론적 순서로 정렬한다 — 그러지 않으면
    /// Dictionary 순회 순서 때문에 ContextBuilder 출력과 스냅샷 테스트가
    /// 실행마다 달라진다 (수정 지침 A-2).
    public func inventory(of owner: EntityID) -> [Item] {
        items.values
            .filter { $0.placement == .inventory(owner) }
            .sorted { $0.name < $1.name }
    }
}
