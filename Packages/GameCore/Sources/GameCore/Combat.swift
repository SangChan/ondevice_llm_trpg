/// 공격 판정의 결과. `GameEngine.attack`과 `AggressiveBehavior.act` 양쪽에서
/// 같은 주사위·데미지 계산을 쓰기 위해 공통화했다 — 반복 로직을 두 번째로
/// 베끼는 순간 바로 추출한다.
struct AttackResolution: Sendable {
    let attackRoll: Int
    let hit: Bool
    let damageDie: Int
    let damageRoll: Int?
    let damage: Int?
}

enum CombatMath {
    /// 원본 설계 §11의 판정 순서를 그대로 따른다: d20 + strength 대 armorClass,
    /// 명중 시 무기(또는 기본 d8) 데미지 주사위.
    static func resolveAttack(
        attackerStrength: Int,
        weaponEffect: ItemEffect,
        targetArmorClass: Int,
        dice: inout Dice
    ) -> AttackResolution {
        let attackRoll = dice.roll(.attack, sides: 20)
        let total = attackRoll + attackerStrength
        let (die, bonus) = weaponEffect.weaponStats ?? (8, 0)

        guard total >= targetArmorClass else {
            return AttackResolution(attackRoll: attackRoll, hit: false, damageDie: die, damageRoll: nil, damage: nil)
        }

        let damageRoll = dice.roll(.damage, sides: die)
        let damage = max(0, damageRoll + bonus)
        return AttackResolution(attackRoll: attackRoll, hit: true, damageDie: die, damageRoll: damageRoll, damage: damage)
    }
}
