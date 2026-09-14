import GameCore

/// 최초 대면 / 적대 / 우호 등 대사가 갈리는 조건 (보강판 §31).
/// Phase 2에서는 `.always`만 실제로 선택된다 — 나머지는 §16 NPC Memory(5단계)에서
/// "이미 만난 적 있는가/퀘스트 상태" 같은 추적이 생긴 뒤에 의미가 생긴다.
/// 지금 매칭 안 되는 조건을 넣는 것보다, 스키마만 미리 맞춰 두는 편이 이후 재작업이 적다.
public enum ScenarioCondition: Sendable, Equatable, Codable {
    case always
    case firstMeeting
    case hostile
    case friendly
}

public struct ScenarioLine: Sendable, Equatable, Codable {
    public let condition: ScenarioCondition
    public let text: String

    public init(condition: ScenarioCondition, text: String) {
        self.condition = condition
        self.text = text
    }
}

/// 이벤트별 대체 문장을 걸 수 있는 지점. Phase 2에서는 NPC 처치만 쓴다.
public enum ScenarioTrigger: Sendable, Equatable, Codable, Hashable {
    case npcDefeated(EntityID)
}

/// 작가가 미리 쓴 시나리오 텍스트 (보강판 §31). Classic Mode의 본문이자, AI Mode에서
/// ContextBuilder가 참고할 월드 시드이며, guardrail 거부 시의 대체 텍스트이기도 하다
/// (Phase 3에서 이 세 번째 용도가 쓰인다).
public struct ScenarioScript: Sendable, Codable {
    public let locationDescriptions: [EntityID: String]
    public let npcLines: [EntityID: [ScenarioLine]]
    public let eventOverrides: [ScenarioTrigger: String]

    public init(
        locationDescriptions: [EntityID: String],
        npcLines: [EntityID: [ScenarioLine]],
        eventOverrides: [ScenarioTrigger: String] = [:]
    ) {
        self.locationDescriptions = locationDescriptions
        self.npcLines = npcLines
        self.eventOverrides = eventOverrides
    }
}
