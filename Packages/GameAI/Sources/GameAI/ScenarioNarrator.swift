import GameCore

/// Classic Mode의 서사 본체. 시나리오에 적혀 있는 사건은 작가의 문장을 쓰고,
/// 적혀 있지 않은 사건(전투 결과 등 조합 가능한 것들)은 `TemplateNarrator`로 잇는다
/// (보강판 §31 "1층/2층").
public struct ScenarioNarrator: Narrating {
    public let script: ScenarioScript
    public let fallback: TemplateNarrator

    public init(script: ScenarioScript, fallback: TemplateNarrator = TemplateNarrator()) {
        self.script = script
        self.fallback = fallback
    }

    public func narrate(_ context: NarrationContext) async throws -> String {
        var parts: [String] = []
        var residual: [GameEvent] = []

        for event in context.recentEvents {
            if let scripted = scriptedLine(for: event) {
                parts.append(scripted)
            } else {
                residual.append(event)
            }
        }

        if !residual.isEmpty {
            let residualContext = NarrationContext(
                playerID: context.playerID,
                locationName: context.locationName,
                recentEvents: residual,
                entityNames: context.entityNames
            )
            parts.append(try await fallback.narrate(residualContext))
        }

        return parts.isEmpty ? "Nothing happens." : parts.joined(separator: " ")
    }

    private func scriptedLine(for event: GameEvent) -> String? {
        switch event {
        case .moved(_, _, let to):
            return script.locationDescriptions[to]
        case .talked(_, let target, _):
            return script.npcLines[target]?.first(where: { $0.condition == .always })?.text
        case .entityDied(let entity):
            return script.eventOverrides[.npcDefeated(entity)]
        default:
            return nil
        }
    }
}
