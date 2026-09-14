import Testing
@testable import GameCore

@Suite("GameEngine — talk")
struct GameEngineTalkTests {
    @Test("talking to a present NPC succeeds")
    func talkToPresentNPCSucceeds() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.friendlyID] = Fixtures.friendlyNPC()
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.friendlyID, message: "Hello")))

        #expect(result.outcome == .success)
        #expect(result.events.contains(.talked(actor: Fixtures.playerID, target: Fixtures.friendlyID, message: "Hello")))
    }

    @Test("talking to an NPC in another location fails")
    func talkToNPCElsewhereFails() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.friendlyID] = Fixtures.friendlyNPC(location: Fixtures.caveID)
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.friendlyID, message: "Hello")))

        #expect(result.outcome == .failure(.targetNotHere))
    }

    @Test("talking to a dead NPC fails")
    func talkToDeadNPCFails() async {
        var initial = Fixtures.baseState()
        initial.npcs[Fixtures.friendlyID] = {
            var npc = Fixtures.friendlyNPC()
            npc.stats.hp = 0
            return npc
        }()
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.friendlyID, message: "Hello")))

        #expect(result.outcome == .failure(.targetAlreadyDead))
    }
}
