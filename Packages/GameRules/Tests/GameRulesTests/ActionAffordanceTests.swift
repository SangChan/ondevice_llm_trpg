import Testing
import GameCore
@testable import GameRules

@Suite("ActionAffordance")
struct ActionAffordanceTests {
    @Test("affordances always include look")
    func alwaysIncludesLook() {
        let state = Fixtures.state()
        let affordances = state.affordances(for: Fixtures.playerID)
        #expect(affordances.contains { $0.id == "look" })
    }

    @Test("affordances include move, talk, attack, and take for what's visible")
    func includesActionsForVisibleEntities() {
        let state = Fixtures.state()
        let affordances = state.affordances(for: Fixtures.playerID)
        let ids = Set(affordances.map(\.id))

        #expect(ids.contains("move:\(Fixtures.caveID.rawValue.uuidString)"))
        #expect(ids.contains("talk:\(Fixtures.hunterID.rawValue.uuidString)"))
        #expect(ids.contains("attack:\(Fixtures.hunterID.rawValue.uuidString)"))
        #expect(ids.contains("take:\(Fixtures.swordID.rawValue.uuidString)"))
    }

    @Test("dead NPCs offer neither talk nor attack")
    func deadNPCsOfferNoInteraction() {
        var state = Fixtures.state()
        state.npcs[Fixtures.hunterID]?.stats.hp = 0

        let affordances = state.affordances(for: Fixtures.playerID)
        let ids = Set(affordances.map(\.id))

        #expect(!ids.contains("talk:\(Fixtures.hunterID.rawValue.uuidString)"))
        #expect(!ids.contains("attack:\(Fixtures.hunterID.rawValue.uuidString)"))
    }

    @Test("only consumables in inventory offer a use affordance")
    func onlyConsumablesOfferUse() {
        var state = Fixtures.state()
        state.items[Fixtures.potionID]?.placement = .inventory(Fixtures.playerID)
        state.items[Fixtures.swordID]?.placement = .inventory(Fixtures.playerID)

        let affordances = state.affordances(for: Fixtures.playerID)
        let ids = Set(affordances.map(\.id))

        #expect(ids.contains("use:\(Fixtures.potionID.rawValue.uuidString)"))
        #expect(!ids.contains("use:\(Fixtures.swordID.rawValue.uuidString)"))
    }

    @Test("hidden items never appear as a take affordance")
    func hiddenItemsAreExcluded() {
        var state = Fixtures.state()
        state.items[Fixtures.swordID]?.isHidden = true

        let affordances = state.affordances(for: Fixtures.playerID)

        #expect(!affordances.contains { $0.id == "take:\(Fixtures.swordID.rawValue.uuidString)" })
    }

    @Test("affordance ordering is deterministic across calls")
    func orderingIsDeterministic() {
        let state = Fixtures.state()
        let first = state.affordances(for: Fixtures.playerID).map(\.id)
        let second = state.affordances(for: Fixtures.playerID).map(\.id)
        #expect(first == second)
    }
}
