import Testing
import GameCore
@testable import GameRules

@Suite("ActionResolver")
struct ActionResolverTests {
    let resolver = ActionResolver()

    @Test("look always resolves without needing a target")
    func lookResolvesUnconditionally() {
        let result = resolver.resolve(PlayerIntent(kind: .look), actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .resolved(.observe(ObserveAction(actor: Fixtures.playerID))))
    }

    @Test("unknown intent is unsupported, never reaches the engine")
    func unknownIsUnsupported() {
        let result = resolver.resolve(PlayerIntent(kind: .unknown, target: "juggle"), actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .unsupported)
    }

    @Test("move resolves an exact connection name to a MoveAction")
    func moveResolvesExactName() {
        let result = resolver.resolve(PlayerIntent(kind: .move, target: "dark cave"), actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .resolved(.move(MoveAction(actor: Fixtures.playerID, destination: Fixtures.caveID))))
    }

    @Test("move to somewhere not connected is notFound, not a GameEngine failure")
    func moveToUnknownPlaceIsNotFound() {
        let result = resolver.resolve(PlayerIntent(kind: .move, target: "the moon"), actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .notFound(term: "the moon"))
    }

    @Test("talk resolves to the visible NPC and carries the spoken message")
    func talkResolvesWithSpeech() {
        let intent = PlayerIntent(kind: .talk, target: "hunter", speech: "Who are you?")
        let result = resolver.resolve(intent, actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .resolved(.talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.hunterID, message: "Who are you?"))))
    }

    @Test("talk without explicit speech defaults to a greeting")
    func talkWithoutSpeechDefaultsToGreeting() {
        let result = resolver.resolve(PlayerIntent(kind: .talk, target: "hunter"), actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .resolved(.talk(TalkAction(actor: Fixtures.playerID, target: Fixtures.hunterID, message: "Hello."))))
    }

    @Test("talk to an NPC in another location is notFound — it isn't in the whitelist")
    func talkToNPCElsewhereIsNotFound() {
        let result = resolver.resolve(PlayerIntent(kind: .talk, target: "goblin"), actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .notFound(term: "goblin"))
    }

    @Test("attack picks up the player's only weapon automatically")
    func attackAutoSelectsWeapon() {
        var state = Fixtures.state()
        state.player.location = Fixtures.caveID
        state.items[Fixtures.swordID]?.placement = .inventory(Fixtures.playerID)

        let result = resolver.resolve(PlayerIntent(kind: .attack, target: "goblin"), actor: Fixtures.playerID, in: state)

        #expect(result == .resolved(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID, weapon: Fixtures.swordID))))
    }

    @Test("attack with no weapon in inventory attacks unarmed")
    func attackWithNoWeaponIsUnarmed() {
        var state = Fixtures.state()
        state.player.location = Fixtures.caveID

        let result = resolver.resolve(PlayerIntent(kind: .attack, target: "goblin"), actor: Fixtures.playerID, in: state)

        #expect(result == .resolved(.attack(AttackAction(attacker: Fixtures.playerID, target: Fixtures.goblinID, weapon: nil))))
    }

    @Test("take resolves a ground item in the current location")
    func takeResolvesGroundItem() {
        let result = resolver.resolve(PlayerIntent(kind: .take, target: "sword"), actor: Fixtures.playerID, in: Fixtures.state())
        #expect(result == .resolved(.takeItem(TakeItemAction(actor: Fixtures.playerID, item: Fixtures.swordID))))
    }

    @Test("take does not see items already in inventory or elsewhere")
    func takeIgnoresNonGroundItems() {
        var state = Fixtures.state()
        state.items[Fixtures.swordID]?.placement = .inventory(Fixtures.playerID)

        let result = resolver.resolve(PlayerIntent(kind: .take, target: "sword"), actor: Fixtures.playerID, in: state)

        #expect(result == .notFound(term: "sword"))
    }

    @Test("use resolves an inventory item, never a ground item")
    func useResolvesInventoryOnly() {
        var state = Fixtures.state()
        state.items[Fixtures.potionID]?.placement = .inventory(Fixtures.playerID)

        let result = resolver.resolve(PlayerIntent(kind: .use, target: "potion"), actor: Fixtures.playerID, in: state)

        #expect(result == .resolved(.useItem(UseItemAction(actor: Fixtures.playerID, item: Fixtures.potionID))))
    }

    @Test("ambiguous term with two matching NPCs asks instead of guessing")
    func ambiguousTermReturnsAllCandidates() {
        var state = Fixtures.state()
        let secondHunter = NPC(
            id: EntityID(),
            name: "Young Hunter",
            location: Fixtures.clearingID,
            stats: Stats(hp: 8, maxHP: 8, strength: 1, dexterity: 1, armorClass: 9),
            disposition: .friendly
        )
        state.npcs[secondHunter.id] = secondHunter

        let result = resolver.resolve(PlayerIntent(kind: .talk, target: "hunter"), actor: Fixtures.playerID, in: state)

        guard case .ambiguous(let candidates) = result else {
            Issue.record("expected .ambiguous, got \(result)")
            return
        }
        #expect(Set(candidates) == Set([Fixtures.hunterID, secondHunter.id]))
    }
}
