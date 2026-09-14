import GameCore

/// 전투 결과·이동·아이템 획득처럼 조합 가능한 사건을 기계적으로 문장화한다
/// (보강판 §31 "2층: TemplateNarrator"). Classic Mode의 접착제이자, AI Mode
/// guardrail 거부 시의 폴백(§33)이기도 하다.
public struct TemplateNarrator: Narrating {
    public init() {}

    public func narrate(_ context: NarrationContext) async throws -> String {
        let sentences = context.recentEvents.compactMap { sentence(for: $0, context: context) }
        return sentences.isEmpty ? "Nothing happens." : sentences.joined(separator: " ")
    }

    private func sentence(for event: GameEvent, context: NarrationContext) -> String? {
        func name(_ id: EntityID) -> String {
            id == context.playerID ? "You" : (context.entityNames[id] ?? "something")
        }
        // 주어가 플레이어면 2인칭 동사형, 아니면 3인칭 동사형을 쓴다.
        func verb(_ id: EntityID, third: String, second: String) -> String {
            id == context.playerID ? second : third
        }

        switch event {
        case .moved(_, _, let to):
            return "You move to \(context.entityNames[to] ?? "a new place")."
        case .observed:
            return nil // "둘러본다" 자체는 서사가 없다 — 장소 묘사는 다른 경로로 나온다.
        case .talked(_, let target, _):
            return "You speak with \(name(target))."
        case .attackHit(let attacker, let target, _):
            // 데미지 수치는 넣지 않는다 — 숫자는 UI가 보여주고 서사는 LLM(또는 템플릿)의 몫이다(§36).
            return "\(name(attacker)) \(verb(attacker, third: "strikes", second: "strike")) \(name(target))."
        case .attackMissed(let attacker, let target):
            return "\(name(attacker)) \(verb(attacker, third: "attacks", second: "attack")) \(name(target)) and \(verb(attacker, third: "misses", second: "miss"))."
        case .entityDied(let entity):
            return "\(name(entity)) \(verb(entity, third: "falls", second: "fall"))."
        case .itemTaken(_, let item):
            return "You pick up \(context.entityNames[item] ?? "the item")."
        case .itemUsed(_, let item, _):
            return "You use \(context.entityNames[item] ?? "the item")."
        case .actionRejected(let reason):
            return Self.rejectionSentence(reason)
        case .rolled:
            return nil // ContextBuilder/narrator 모두 주사위 눈은 절대 서사에 넣지 않는다(수정 지침 C).
        }
    }

    private static func rejectionSentence(_ reason: ActionFailure) -> String {
        switch reason {
        case .actorNotFound:
            return "That doesn't seem possible."
        case .targetNotFound:
            return "There is nothing like that here."
        case .targetNotHere:
            return "That isn't here."
        case .targetAlreadyDead:
            return "That target is already dead."
        case .noConnection:
            return "You cannot go that way."
        case .itemNotHere:
            return "There's nothing like that to take."
        case .itemNotInInventory:
            return "You don't have that."
        case .itemNotUsable:
            return "You can't use that."
        }
    }
}
