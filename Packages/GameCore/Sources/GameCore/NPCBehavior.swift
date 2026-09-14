/// NPC의 행동 "선택"은 결정론적 규칙이다. NPC의 "대사"만 LLM이 만든다 —
/// 이 경계는 원본 설계 §3의 철학과 정확히 일치한다 (수정 지침 §35).
public protocol NPCBehavior: Sendable {
    func act(_ npc: NPC, in state: inout GameState, dice: inout Dice) -> [GameEvent]
}

/// 같은 장소 + 적대 성향이면 플레이어를 공격한다. MVP의 유일한 NPCBehavior 구현체.
public struct AggressiveBehavior: NPCBehavior {
    public init() {}

    public func act(_ npc: NPC, in state: inout GameState, dice: inout Dice) -> [GameEvent] {
        guard npc.disposition == .hostile, npc.stats.isAlive else { return [] }
        guard npc.location == state.player.location else { return [] }
        guard state.player.stats.isAlive else { return [] }

        var events: [GameEvent] = []

        let resolution = CombatMath.resolveAttack(
            attackerStrength: npc.stats.strength,
            weaponEffect: .none,
            targetArmorClass: state.player.stats.armorClass,
            dice: &dice
        )
        events.append(.rolled(kind: .attack, sides: 20, result: resolution.attackRoll))

        guard resolution.hit, let damage = resolution.damage, let damageRoll = resolution.damageRoll else {
            events.append(.attackMissed(attacker: npc.id, target: state.player.id))
            return events
        }

        events.append(.rolled(kind: .damage, sides: resolution.damageDie, result: damageRoll))
        state.player.stats.hp -= damage
        events.append(.attackHit(attacker: npc.id, target: state.player.id, damage: damage))

        if !state.player.stats.isAlive {
            events.append(.entityDied(entity: state.player.id))
        }

        return events
    }
}
