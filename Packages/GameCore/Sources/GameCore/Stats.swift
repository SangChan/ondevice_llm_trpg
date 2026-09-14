/// 전투 능력치. `Player`/`NPC`의 공통 부분 (수정 지침 A-1).
public struct Stats: Codable, Sendable, Equatable {
    public var hp: Int
    public let maxHP: Int
    public var strength: Int
    public var dexterity: Int
    public var armorClass: Int

    public init(hp: Int, maxHP: Int, strength: Int, dexterity: Int, armorClass: Int) {
        self.hp = hp
        self.maxHP = maxHP
        self.strength = strength
        self.dexterity = dexterity
        self.armorClass = armorClass
    }

    public var isAlive: Bool { hp > 0 }
}

/// 전투에 참여할 수 있는 엔티티의 공통 인터페이스 (수정 지침 A-1).
/// `Player`와 `NPC`를 하나의 전투 파이프라인에서 다루기 위한 경계.
public protocol Combatant: Sendable {
    var id: EntityID { get }
    var name: String { get }
    var location: EntityID { get }
    var stats: Stats { get }
}
