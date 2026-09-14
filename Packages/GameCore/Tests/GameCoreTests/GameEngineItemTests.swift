import Testing
@testable import GameCore

@Suite("GameEngine — take / use item")
struct GameEngineItemTests {
    @Test("taking an item on the ground moves it into inventory")
    func takingItemMovesPlacement() async {
        var initial = Fixtures.baseState()
        let sword = Fixtures.sword()
        initial.items[sword.id] = sword
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.takeItem(TakeItemAction(actor: Fixtures.playerID, item: sword.id)))

        #expect(result.outcome == .success)
        #expect(result.events.contains(.itemTaken(actor: Fixtures.playerID, item: sword.id)))

        let state = await engine.currentState
        #expect(state.items[sword.id]?.placement == .inventory(Fixtures.playerID))
        #expect(state.inventory(of: Fixtures.playerID).map(\.id) == [sword.id])
    }

    @Test("taking an item that is not in the player's location fails")
    func takingItemElsewhereFails() async {
        var initial = Fixtures.baseState()
        var sword = Fixtures.sword()
        sword.placement = .location(Fixtures.caveID)
        initial.items[sword.id] = sword
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.takeItem(TakeItemAction(actor: Fixtures.playerID, item: sword.id)))

        #expect(result.outcome == .failure(.itemNotHere))
    }

    @Test("using a consumable heals the player and consumes the item")
    func usingConsumableHealsAndConsumes() async {
        var initial = Fixtures.baseState(seed: 1)
        initial.player.stats.hp = 10
        let potion = Fixtures.potion()
        initial.items[potion.id] = potion
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.useItem(UseItemAction(actor: Fixtures.playerID, item: potion.id)))

        #expect(result.outcome == .success)
        #expect(result.events.contains(.itemUsed(actor: Fixtures.playerID, item: potion.id, target: nil)))

        let state = await engine.currentState
        #expect(state.player.stats.hp == 15)
        #expect(state.items[potion.id]?.placement == .consumed)
    }

    @Test("healing never exceeds maxHP")
    func healingIsCappedAtMaxHP() async {
        var initial = Fixtures.baseState(seed: 1)
        initial.player.stats.hp = 18 // maxHP == 20, potion heals 5
        let potion = Fixtures.potion()
        initial.items[potion.id] = potion
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        _ = await engine.execute(.useItem(UseItemAction(actor: Fixtures.playerID, item: potion.id)))

        let state = await engine.currentState
        #expect(state.player.stats.hp == 20)
    }

    @Test("using a weapon (not consumable) is rejected")
    func usingWeaponIsRejected() async {
        var initial = Fixtures.baseState()
        var sword = Fixtures.sword()
        sword.placement = .inventory(Fixtures.playerID)
        initial.items[sword.id] = sword
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.useItem(UseItemAction(actor: Fixtures.playerID, item: sword.id)))

        #expect(result.outcome == .failure(.itemNotUsable))
    }

    @Test("using an item not in inventory is rejected")
    func usingItemNotInInventoryIsRejected() async {
        let initial = Fixtures.baseState()
        let potion = Fixtures.potion() // still on the ground conceptually — but not registered at all here
        let engine = GameEngine(state: initial, dice: Dice(seed: 1))

        let result = await engine.execute(.useItem(UseItemAction(actor: Fixtures.playerID, item: potion.id)))

        #expect(result.outcome == .failure(.itemNotInInventory))
    }
}
