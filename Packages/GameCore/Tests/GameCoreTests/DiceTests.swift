import Testing
@testable import GameCore

@Suite("Dice")
struct DiceTests {
    @Test("same seed produces same roll sequence")
    func sameSeedProducesSameSequence() {
        var a = Dice(seed: 42)
        var b = Dice(seed: 42)

        let rollsA = (0..<10).map { _ in a.roll(.attack, sides: 20) }
        let rollsB = (0..<10).map { _ in b.roll(.attack, sides: 20) }

        #expect(rollsA == rollsB)
        #expect(rollsA.allSatisfy { (1...20).contains($0) })
    }

    @Test("scripted rolls are returned in order before falling back to seed")
    func scriptedRollsReturnInOrder() {
        var dice = Dice(scripted: [20, 1, 5])

        #expect(dice.roll(.attack, sides: 20) == 20)
        #expect(dice.roll(.attack, sides: 20) == 1)
        #expect(dice.roll(.damage, sides: 8) == 5)
        // 스크립트가 소진되면 시드 RNG로 넘어간다 — 크래시하지 않는다.
        #expect((1...8).contains(dice.roll(.damage, sides: 8)))
    }
}
