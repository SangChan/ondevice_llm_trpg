import Testing
import GameCore
@testable import GameAI

@Suite("TemplateNarrator")
struct TemplateNarratorTests {
    let narrator = TemplateNarrator()
    let playerID = EntityID()
    let goblinID = EntityID()

    private func context(_ events: [GameEvent]) -> NarrationContext {
        NarrationContext(
            playerID: playerID,
            locationName: "Dark Cave",
            recentEvents: events,
            entityNames: [playerID: "Hero", goblinID: "Goblin Scout"]
        )
    }

    @Test("no events narrates as nothing happening")
    func noEventsNarratesAsNothingHappening() async throws {
        let text = try await narrator.narrate(context([]))
        #expect(text == "Nothing happens.")
    }

    @Test("rolled events never appear in the narration")
    func rolledEventsAreExcluded() async throws {
        let text = try await narrator.narrate(context([.rolled(kind: .attack, sides: 20, result: 17)]))
        #expect(text == "Nothing happens.")
    }

    @Test("damage numbers never appear in the narration")
    func damageNumbersAreExcluded() async throws {
        let text = try await narrator.narrate(context([.attackHit(attacker: playerID, target: goblinID, damage: 12)]))
        #expect(!text.contains("12"))
    }

    @Test("player-initiated events use second person, others third person")
    func personSwitchesOnPlayerVsOther() async throws {
        let playerHits = try await narrator.narrate(context([.attackHit(attacker: playerID, target: goblinID, damage: 3)]))
        #expect(playerHits == "You strike Goblin Scout.")

        let goblinHits = try await narrator.narrate(context([.attackHit(attacker: goblinID, target: playerID, damage: 3)]))
        #expect(goblinHits == "Goblin Scout strikes You.")
    }

    @Test("actionRejected maps to a rejection sentence, not a raw case name")
    func actionRejectedMapsToSentence() async throws {
        let text = try await narrator.narrate(context([.actionRejected(reason: .noConnection)]))
        #expect(text == "You cannot go that way.")
    }

    @Test("multiple events in one turn join into multiple sentences")
    func multipleEventsJoinIntoSentences() async throws {
        let text = try await narrator.narrate(context([
            .attackMissed(attacker: playerID, target: goblinID),
            .entityDied(entity: goblinID)
        ]))
        #expect(text == "You attack Goblin Scout and miss. Goblin Scout falls.")
    }
}
