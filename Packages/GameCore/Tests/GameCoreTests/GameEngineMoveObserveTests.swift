import Testing
@testable import GameCore

@Suite("GameEngine — move / observe")
struct GameEngineMoveObserveTests {
    @Test("moving through a connection succeeds and advances the turn")
    func moveThroughConnectionSucceeds() async {
        let engine = GameEngine(state: Fixtures.baseState(), dice: Dice(seed: 1))

        let result = await engine.execute(.move(MoveAction(actor: Fixtures.playerID, destination: Fixtures.caveID)))

        #expect(result.outcome == .success)
        #expect(result.events.contains(.moved(actor: Fixtures.playerID, from: Fixtures.forestID, to: Fixtures.caveID)))

        let state = await engine.currentState
        #expect(state.player.location == Fixtures.caveID)
        #expect(state.turn == 1)
    }

    @Test("moving to a disconnected location fails without consuming a turn")
    func moveToDisconnectedLocationFails() async {
        let unreachable = EntityID()
        var initial = Fixtures.baseState()
        initial.locations[unreachable] = Location(id: unreachable, name: "Far Tower")
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.move(MoveAction(actor: Fixtures.playerID, destination: unreachable)))

        #expect(result.outcome == .failure(.noConnection))
        let state = await engine.currentState
        #expect(state.player.location == Fixtures.forestID)
        #expect(state.turn == 0)
    }

    @Test("observe is free — it does not advance the turn or trigger NPC actions")
    func observeIsFree() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.goblinID] = Fixtures.goblin()
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.observe(ObserveAction(actor: Fixtures.playerID)))

        #expect(result.outcome == .success)
        #expect(result.events == [.observed(actor: Fixtures.playerID, location: Fixtures.forestID)])

        let state = await engine.currentState
        #expect(state.turn == 0)
        #expect(state.player.stats.hp == 20) // 고블린이 공격하지 않았다
    }

    @Test("acting as another entity is rejected")
    func actingAsAnotherEntityIsRejected() async {
        let engine = GameEngine(state: Fixtures.baseState(), dice: Dice(seed: 1))
        let impostor = EntityID()

        let result = await engine.execute(.observe(ObserveAction(actor: impostor)))

        #expect(result.outcome == .failure(.actorNotFound))
    }
}
