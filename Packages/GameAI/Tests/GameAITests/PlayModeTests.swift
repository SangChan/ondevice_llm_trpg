import FoundationModels
import Testing
@testable import GameAI

@Suite("PlayMode")
struct PlayModeTests {
    @Test("available maps to AI mode")
    func availableMapsToAIMode() {
        #expect(PlayMode.resolve(from: .available) == .ai)
    }

    @Test("each unavailable reason maps to the matching Classic reason")
    func unavailableReasonsMapToClassicReasons() {
        #expect(PlayMode.resolve(from: .unavailable(.deviceNotEligible)) == .classic(reason: .deviceNotEligible))
        #expect(PlayMode.resolve(from: .unavailable(.appleIntelligenceNotEnabled)) == .classic(reason: .appleIntelligenceNotEnabled))
        #expect(PlayMode.resolve(from: .unavailable(.modelNotReady)) == .classic(reason: .modelNotReady))
    }
}
