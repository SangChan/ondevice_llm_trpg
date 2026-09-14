/// 게임 상태를 독점적으로 변경하는 actor (원본 설계 §9).
/// LLM은 여기로 들어오지 않는다 — 들어오는 것은 이미 EntityID까지 해석된
/// `GameAction`뿐이다.
public actor GameEngine {
    private var state: GameState
    private var dice: Dice
    private let behavior: any NPCBehavior

    public init(state: GameState, dice: Dice, behavior: any NPCBehavior = AggressiveBehavior()) {
        self.state = state
        self.dice = dice
        self.behavior = behavior
    }

    public var currentState: GameState { state }

    /// 성공하고 `turnCost == .full`인 행동만 세계를 전진시킨다 (수정 지침 §35).
    /// 실패는 게임 시간을 소비하지 않는다.
    public func execute(_ action: GameAction) -> ActionResult {
        let result = perform(action)

        guard case .success = result.outcome else {
            return result
        }
        guard action.turnCost == .full else {
            return result
        }

        var events = result.events
        events += advanceWorld()
        state.turn += 1

        return ActionResult(outcome: .success, events: events)
    }

    private func perform(_ action: GameAction) -> ActionResult {
        switch action {
        case .move(let action): return move(action)
        case .observe(let action): return observe(action)
        case .talk(let action): return talk(action)
        case .attack(let action): return attack(action)
        case .takeItem(let action): return takeItem(action)
        case .useItem(let action): return useItem(action)
        }
    }

    /// 플레이어가 있는 장소의 살아있는 적대 NPC를 결정론적 순서로 행동시킨다
    /// (수정 지침 §35). 이것이 없으면 NPC가 가만히 맞다가 죽는 게임이 된다.
    private func advanceWorld() -> [GameEvent] {
        var events: [GameEvent] = []

        let actors = state.npcs.values
            .filter { $0.location == state.player.location }
            .filter { $0.stats.isAlive }
            .filter { $0.disposition == .hostile }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }

        for npc in actors {
            events += behavior.act(npc, in: &state, dice: &dice)
        }

        return events
    }

    // MARK: - Move

    private func move(_ action: MoveAction) -> ActionResult {
        guard action.actor == state.player.id else {
            return ActionResult(outcome: .failure(.actorNotFound), events: [])
        }
        guard let current = state.locations[state.player.location] else {
            return ActionResult(outcome: .failure(.actorNotFound), events: [])
        }
        guard current.connections.contains(action.destination),
              state.locations[action.destination] != nil else {
            return ActionResult(outcome: .failure(.noConnection), events: [])
        }

        let from = state.player.location
        state.player.location = action.destination

        return ActionResult(outcome: .success, events: [
            .moved(actor: action.actor, from: from, to: action.destination)
        ])
    }

    // MARK: - Observe

    private func observe(_ action: ObserveAction) -> ActionResult {
        guard action.actor == state.player.id else {
            return ActionResult(outcome: .failure(.actorNotFound), events: [])
        }
        return ActionResult(outcome: .success, events: [
            .observed(actor: action.actor, location: state.player.location)
        ])
    }

    // MARK: - Talk

    private func talk(_ action: TalkAction) -> ActionResult {
        guard action.actor == state.player.id else {
            return ActionResult(outcome: .failure(.actorNotFound), events: [])
        }
        guard let target = state.npcs[action.target] else {
            return ActionResult(outcome: .failure(.targetNotFound), events: [])
        }
        guard target.location == state.player.location else {
            return ActionResult(outcome: .failure(.targetNotHere), events: [])
        }
        guard target.stats.isAlive else {
            return ActionResult(outcome: .failure(.targetAlreadyDead), events: [])
        }

        return ActionResult(outcome: .success, events: [
            .talked(actor: action.actor, target: action.target, message: action.message)
        ])
    }

    // MARK: - Attack

    private func attack(_ action: AttackAction) -> ActionResult {
        guard action.attacker == state.player.id else {
            return ActionResult(outcome: .failure(.actorNotFound), events: [])
        }
        guard let target = state.npcs[action.target] else {
            return ActionResult(outcome: .failure(.targetNotFound), events: [])
        }
        guard target.location == state.player.location else {
            return ActionResult(outcome: .failure(.targetNotHere), events: [])
        }
        guard target.stats.isAlive else {
            return ActionResult(outcome: .failure(.targetAlreadyDead), events: [])
        }

        var weaponEffect: ItemEffect = .none
        if let weaponID = action.weapon {
            guard let weapon = state.items[weaponID],
                  weapon.placement == .inventory(action.attacker) else {
                return ActionResult(outcome: .failure(.itemNotInInventory), events: [])
            }
            weaponEffect = weapon.effect
        }

        let resolution = CombatMath.resolveAttack(
            attackerStrength: state.player.stats.strength,
            weaponEffect: weaponEffect,
            targetArmorClass: target.stats.armorClass,
            dice: &dice
        )

        var events: [GameEvent] = [.rolled(kind: .attack, sides: 20, result: resolution.attackRoll)]

        guard resolution.hit, let damage = resolution.damage, let damageRoll = resolution.damageRoll else {
            events.append(.attackMissed(attacker: action.attacker, target: action.target))
            return ActionResult(outcome: .success, events: events)
        }

        events.append(.rolled(kind: .damage, sides: resolution.damageDie, result: damageRoll))
        state.npcs[action.target]?.stats.hp -= damage
        events.append(.attackHit(attacker: action.attacker, target: action.target, damage: damage))

        if state.npcs[action.target]?.stats.isAlive == false {
            events.append(.entityDied(entity: action.target))
        }

        return ActionResult(outcome: .success, events: events)
    }

    // MARK: - Take Item

    private func takeItem(_ action: TakeItemAction) -> ActionResult {
        guard action.actor == state.player.id else {
            return ActionResult(outcome: .failure(.actorNotFound), events: [])
        }
        guard let item = state.items[action.item] else {
            return ActionResult(outcome: .failure(.itemNotHere), events: [])
        }
        guard item.placement == .location(state.player.location) else {
            return ActionResult(outcome: .failure(.itemNotHere), events: [])
        }

        state.items[action.item]?.placement = .inventory(action.actor)

        return ActionResult(outcome: .success, events: [
            .itemTaken(actor: action.actor, item: action.item)
        ])
    }

    // MARK: - Use Item

    private func useItem(_ action: UseItemAction) -> ActionResult {
        guard action.actor == state.player.id else {
            return ActionResult(outcome: .failure(.actorNotFound), events: [])
        }
        guard let item = state.items[action.item] else {
            return ActionResult(outcome: .failure(.itemNotInInventory), events: [])
        }
        guard item.placement == .inventory(action.actor) else {
            return ActionResult(outcome: .failure(.itemNotInInventory), events: [])
        }

        switch item.effect {
        case .consumable(let healing):
            let targetID = action.target ?? action.actor
            guard targetID == state.player.id else {
                return ActionResult(outcome: .failure(.targetNotFound), events: [])
            }
            state.player.stats.hp = min(state.player.stats.maxHP, state.player.stats.hp + healing)
            state.items[action.item]?.placement = .consumed

            return ActionResult(outcome: .success, events: [
                .itemUsed(actor: action.actor, item: action.item, target: action.target)
            ])

        case .weapon, .none:
            return ActionResult(outcome: .failure(.itemNotUsable), events: [])
        }
    }
}
