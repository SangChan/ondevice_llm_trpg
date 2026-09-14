import Testing
import GameCore
@testable import GameRules

@Suite("Visibility")
struct VisibilityTests {
    @Test("visibleNPCs only returns NPCs in the actor's location")
    func visibleNPCsFiltersByLocation() {
        let state = Fixtures.state()
        let npcs = state.visibleNPCs(for: Fixtures.playerID)
        #expect(npcs == [Fixtures.hunterID: "Old Hunter"])
    }

    @Test("visibleGroundItems excludes hidden items")
    func visibleGroundItemsExcludesHidden() {
        var state = Fixtures.state()
        state.items[Fixtures.swordID]?.isHidden = true

        let items = state.visibleGroundItems(for: Fixtures.playerID)

        #expect(items.isEmpty)
    }

    @Test("visibleConnections lists connected locations by name")
    func visibleConnectionsListsNeighbors() {
        let state = Fixtures.state()
        let connections = state.visibleConnections(for: Fixtures.playerID)
        #expect(connections == [Fixtures.caveID: "Dark Cave"])
    }

    @Test("visibleEntities merges NPCs, ground items, and connections")
    func visibleEntitiesIsUnionOfAllThree() {
        var state = Fixtures.state()
        state.player.location = Fixtures.caveID

        let all = state.visibleEntities(for: Fixtures.playerID)

        #expect(all[Fixtures.goblinID] == "Goblin Scout")
        #expect(all[Fixtures.potionID] == "Healing Potion")
        #expect(all[Fixtures.clearingID] == "Forest Clearing")
        #expect(all[Fixtures.shrineID] == "Old Shrine")
    }
}
