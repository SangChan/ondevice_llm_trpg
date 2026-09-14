import Testing
@testable import GameCore

@Suite("GameEngine — advanceWorld / NPC reactions")
struct AdvanceWorldTests {
    @Test("a hostile NPC in the same location retaliates after a full-cost action")
    func hostileNPCRetaliatesAfterFullAction() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 20)
        // player attack: miss (roll 1). goblin retaliation: hit (roll 20) damage 4.
        let engine = GameEngine(state: initial, dice: Dice(scripted: [1, 20, 4]))

        let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))

        #expect(result.events.contains(.attackHit(attacker: Fixtures.goblinID, target: Fixtures.playerID, damage: 4)))

        let state = await engine.currentState
        #expect(state.player.stats.hp == 16)
        #expect(state.turn == 1)
    }

    @Test("a friendly NPC never retaliates")
    func friendlyNPCNeverRetaliates() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.friendlyID] = Fixtures.friendlyNPC()
        let engine = GameEngine(state: initial, dice: Dice(seed: 7))

        _ = await engine.execute(.talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.friendlyID, message: "Hi")))

        let state = await engine.currentState
        #expect(state.player.stats.hp == 20)
    }

    @Test("a dead hostile NPC does not act")
    func deadHostileNPCDoesNotAct() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 0)
        let dummyDestination = Fixtures.caveID
        let engine = GameEngine(state: initial, dice: Dice(seed: 3))

        _ = await engine.execute(.move(MoveAction(actor: Fixtures.playerID, destination: dummyDestination)))

        let state = await engine.currentState
        #expect(state.player.stats.hp == 20)
    }

    @Test("a hostile NPC in another location does not act")
    func hostileNPCElsewhereDoesNotAct() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(location: Fixtures.caveID)
        let engine = GameEngine(state: initial, dice: Dice(seed: 3))

        _ = await engine.execute(.talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.friendlyID, message: "hi")))
        // talk fails (no such NPC visible) — but regardless, goblin in the cave must not touch the player.

        let state = await engine.currentState
        #expect(state.player.stats.hp == 20)
    }

    @Test("free actions (observe) do not trigger NPC retaliation")
    func freeActionsDoNotTriggerRetaliation() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin()
        let engine = GameEngine(state: initial, dice: Dice(seed: 9))

        _ = await engine.execute(.observe(ObserveAction(actor: Fixtures.playerID)))

        let state = await engine.currentState
        #expect(state.player.stats.hp == 20)
        #expect(state.turn == 0)
    }

    @Test("a fixed seed makes a full combat-to-death sequence fully deterministic")
    func combatToDeathIsDeterministic() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 8)
        let engine = GameEngine(state: initial, dice: Dice(seed: 42))

        var allEvents: [GameEvent] = []
        for _ in 0..<5 {
            let state = await engine.currentState
            guard state.npcs[Fixtures.goblinID]?.stats.isAlive == true else { break }
            let result = await engine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))
            allEvents += result.events
        }

        #expect(allEvents.contains(.entityDied(entity: Fixtures.goblinID)))

        // 같은 시드로 처음부터 다시 실행하면 완전히 같은 이벤트 시퀀스가 나온다.
        var replayState = Fixtures.baseState()
        replayState.npcs[Fixtures.goblinID] = Fixtures.goblin(hp: 8)
        let replayEngine = GameEngine(state: replayState, dice: Dice(seed: 42))

        var replayEvents: [GameEvent] = []
        for _ in 0..<5 {
            let state = await replayEngine.currentState
            guard state.npcs[Fixtures.goblinID]?.stats.isAlive == true else { break }
            let result = await replayEngine.execute(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID)))
            replayEvents += result.events
        }

        #expect(allEvents == replayEvents)
    }
}
