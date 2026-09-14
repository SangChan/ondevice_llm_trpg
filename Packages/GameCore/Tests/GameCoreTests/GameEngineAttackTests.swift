import Testing
@testable import GameCore

@Suite("GameEngine — attack")
struct GameEngineAttackTests {
    @Test("a scripted hit deals scripted damage and can kill the target")
    func scriptedHitKillsTarget() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 5) // armorClass 10
        // attack roll 20 (+3 str = 23, beats AC 10) → hit, damage roll 8
        let engine = GameEngine(state: initial, dice: Dice(scripted: [20, 8]))

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))

        #expect(result.outcome == .success)
        #expect(result.events.contains(.attackHit(attacker: Fixtures.playerID, target: Fixtures.goblinID, damage: 8)))
        #expect(result.events.contains(.entityDied(entity: Fixtures.goblinID)))

        let state = await engine.currentState
        #expect(state.npcs[Fixtures.goblinID]?.stats.hp == -3)
    }

    @Test("a scripted miss deals no damage")
    func scriptedMissDealsNoDamage() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 5)
        // attack roll 1 (+3 str = 4, misses AC 10)
        let engine = GameEngine(state: initial, dice: Dice(scripted: [1]))

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))

        #expect(result.outcome == .success)
        #expect(result.events.contains(.attackMissed(attacker: Fixtures.playerID, target: Fixtures.goblinID)))

        let state = await engine.currentState
        #expect(state.npcs[Fixtures.goblinID]?.stats.hp == 5)
    }

    @Test("a weapon's damage die and bonus are used over the default d8")
    func weaponDamageDieAndBonusApply() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 20)
        var sword = Fixtures.sword() // weapon(damageDie: 8, bonus: 1)
        sword.placement = .inventory(Fixtures.playerID)
        initial.items[sword.id] = sword
        let engine = GameEngine(state: initial, dice: Dice(scripted: [20, 4])) // hit, damage roll 4 + bonus 1

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID, weapon: sword.id)))

        #expect(result.events.contains(.attackHit(attacker: Fixtures.playerID, target: Fixtures.goblinID, damage: 5)))
    }

    @Test("attacking with a weapon not in inventory fails")
    func attackingWithMissingWeaponFails() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin()
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID, weapon: Fixtures.swordID)))

        #expect(result.outcome == .failure(.itemNotInInventory))
    }

    @Test("attacking a target in another location fails")
    func attackingTargetElsewhereFails() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(location: Fixtures.caveID)
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))

        #expect(result.outcome == .failure(.targetNotHere))
    }

    @Test("attacking an already-dead target fails")
    func attackingDeadTargetFails() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 0)
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))

        #expect(result.outcome == .failure(.targetAlreadyDead))
    }

    @Test("rolled events are recorded for both attack and damage rolls")
    func rolledEventsAreRecorded() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 20)
        let engine = GameEngine(state: initial, dice: Dice(scripted: [20, 6]))

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))

        #expect(result.events.contains(.rolled(kind: .attack, sides: 20, result: 20)))
        #expect(result.events.contains(.rolled(kind: .damage, sides: 8, result: 6)))
    }
}
