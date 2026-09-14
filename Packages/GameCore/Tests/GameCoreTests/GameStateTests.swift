import Testing
@testable import GameCore

@Suite("GameState")
struct GameStateTests {
    @Test("inventory only returns items placed in that owner's inventory, sorted by name")
    func inventoryFiltersAndSorts() {
        var state = Fixtures.baseState()
        let potion = Fixtures.potion() // inventory(playerID)
        let swordOnGround = Fixtures.sword() // location(forestID)
        let helmet = Item(
            id: EntityID(),
            name: "Helmet",
            effect: .none,
            placement: .inventory(Fixtures.playerID)
        )
        state.items = [potion.id: potion, swordOnGround.id: swordOnGround, helmet.id: helmet]

        let inventory = state.inventory(of: Fixtures.playerID)

        #expect(inventory.map(\.name) == ["Healing Potion", "Helmet"])
    }

    @Test("schemaVersion defaults to the current version")
    func schemaVersionDefaultsToCurrent() {
        let state = Fixtures.baseState()
        #expect(state.schemaVersion == GameState.currentSchemaVersion)
    }
}
