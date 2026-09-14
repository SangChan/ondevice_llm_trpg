import Testing
import GameCore
@testable import GameRules

@Suite("TranscriptPhrasing")
struct TranscriptPhrasingTests {
    @Test("each action kind produces a first-person English sentence")
    func eachActionKindProducesASentence() {
        let state = Fixtures.state()

        #expect(state.playerSentence(for: .move(MoveAction(actor: Fixtures.playerID, destination: Fixtures.caveID))) == "You go to Dark Cave.")
        #expect(state.playerSentence(for: .observe(ObserveAction(actor: Fixtures.playerID))) == "You look around.")
        #expect(state.playerSentence(for: .talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.hunterID, message: "Hi"))) == "You talk to Old Hunter.")
        #expect(state.playerSentence(for: .attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID))) == "You attack Goblin Scout.")
        #expect(state.playerSentence(for: .takeItem(TakeItemAction(actor: Fixtures.playerID, item: Fixtures.swordID))) == "You take the Rusty Sword.")
        #expect(state.playerSentence(for: .useItem(UseItemAction(actor: Fixtures.playerID, item: Fixtures.potionID))) == "You use the Healing Potion.")
    }
}
