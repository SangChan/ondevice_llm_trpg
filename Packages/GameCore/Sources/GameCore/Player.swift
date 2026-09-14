/// 플레이어. 인벤토리는 별도 필드로 두지 않는다 — `Item.placement`가 단일 소스다 (수정 지침 A-2).
public struct Player: Codable, Sendable, Combatant, Equatable {
    public let id: EntityID
    public var name: String
    public var location: EntityID
    public var stats: Stats

    public init(id: EntityID, name: String, location: EntityID, stats: Stats) {
        self.id = id
        self.name = name
        self.location = location
        self.stats = stats
    }
}
