import Testing
import GameCore
@testable import GameAI

@Suite("ScenarioNarrator")
struct ScenarioNarratorTests {
    let playerID = EntityID()
    let caveID = EntityID()
    let hunterID = EntityID()
    let goblinID = EntityID()

    private func script() -> ScenarioScript {
        ScenarioScript(
            locationDescriptions: [caveID: "The air turns cold and damp."],
            npcLines: [hunterID: [ScenarioLine(condition: .always, text: "\"Careful in there,\" the hunter says.")]],
            eventOverrides: [.npcDefeated(goblinID): "The goblin collapses and the cave falls silent."]
        )
    }

    private func context(_ events: [GameEvent]) -> NarrationContext {
        NarrationContext(
            playerID: playerID,
            locationName: "Dark Cave",
            recentEvents: events,
            entityNames: [caveID: "Dark Cave", hunterID: "Old Hunter", goblinID: "Goblin Scout"]
        )
    }

    @Test("a scripted location description is used verbatim on move")
    func scriptedLocationDescriptionIsUsed() async throws {
        let narrator = ScenarioNarrator(script: script())
        let text = try await narrator.narrate(context([.moved(actor: playerID, from: EntityID(), to: caveID)]))
        #expect(text == "The air turns cold and damp.")
    }

    @Test("a scripted NPC line is used verbatim on talk")
    func scriptedNPCLineIsUsed() async throws {
        let narrator = ScenarioNarrator(script: script())
        let text = try await narrator.narrate(context([.talked(actor: playerID, target: hunterID, message: "hi")]))
        #expect(text == "\"Careful in there,\" the hunter says.")
    }

    @Test("an event override replaces the default death sentence")
    func eventOverrideReplacesDefault() async throws {
        let narrator = ScenarioNarrator(script: script())
        let text = try await narrator.narrate(context([.entityDied(entity: goblinID)]))
        #expect(text == "The goblin collapses and the cave falls silent.")
    }

    @Test("events with no scripted line fall back to the template narrator")
    func unscriptedEventsFallBackToTemplate() async throws {
        let narrator = ScenarioNarrator(script: script())
        let text = try await narrator.narrate(context([.itemTaken(actor: playerID, item: EntityID())]))
        #expect(text == "You pick up the item.")
    }

    @Test("scripted and unscripted events in the same turn both appear")
    func scriptedAndUnscriptedEventsBothAppear() async throws {
        let narrator = ScenarioNarrator(script: script())
        let text = try await narrator.narrate(context([
            .talked(actor: playerID, target: hunterID, message: "hi"),
            .itemTaken(actor: playerID, item: EntityID())
        ]))
        #expect(text == "\"Careful in there,\" the hunter says. You pick up the item.")
    }

    @Test("a location with no scripted description falls back to the template narrator")
    func unscriptedLocationFallsBackToTemplate() async throws {
        let narrator = ScenarioNarrator(script: script())
        let otherLocation = EntityID()
        let text = try await narrator.narrate(context([.moved(actor: playerID, from: caveID, to: otherLocation)]))
        #expect(text == "You move to a new place.")
    }
}
