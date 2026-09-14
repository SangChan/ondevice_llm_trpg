/// NPC의 플레이어에 대한 태도. `disposition`이 없으면 모든 NPC가 적이거나
/// 모든 NPC가 방관자가 된다 (수정 지침 A-1). §35 NPC 행동 선택의 전제.
public enum Disposition: String, Codable, Sendable, Equatable {
    case hostile
    case neutral
    case friendly
}

public struct NPC: Codable, Sendable, Combatant, Equatable {
    public let id: EntityID
    public var name: String
    public var location: EntityID
    public var stats: Stats
    public var disposition: Disposition

    public init(id: EntityID, name: String, location: EntityID, stats: Stats, disposition: Disposition) {
        self.id = id
        self.name = name
        self.location = location
        self.stats = stats
        self.disposition = disposition
    }
}
