/// 아이템의 현재 위치. 바닥 / 인벤토리 / 소비됨 중 하나뿐이다 — 이중 소스를 만들지 않는다
/// (수정 지침 A-2, 원본의 가장 큰 모델 구멍).
public enum ItemPlacement: Codable, Sendable, Hashable {
    case location(EntityID)
    case inventory(EntityID)
    case consumed
}

/// 아이템이 게임 규칙에 미치는 효과 (수정 지침 A-2).
public enum ItemEffect: Codable, Sendable, Equatable {
    case weapon(damageDie: Int, bonus: Int)
    case consumable(healing: Int)
    case none
}

public struct Item: Codable, Sendable, Equatable {
    public let id: EntityID
    public let name: String
    public let effect: ItemEffect
    public var placement: ItemPlacement
    /// 탐색으로 발견되기 전까지 행동 칩(§31-1)에 노출하지 않는다.
    public var isHidden: Bool

    public init(id: EntityID, name: String, effect: ItemEffect, placement: ItemPlacement, isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.effect = effect
        self.placement = placement
        self.isHidden = isHidden
    }
}

extension ItemEffect {
    /// 무기 효과의 (주사위 면 수, 보너스). 무기가 아니면 `nil`.
    var weaponStats: (die: Int, bonus: Int)? {
        if case .weapon(let die, let bonus) = self {
            return (die, bonus)
        }
        return nil
    }
}
