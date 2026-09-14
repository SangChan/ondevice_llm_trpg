import GameCore

/// 자연어 대상 표현을 실제 EntityID로 바꾼다 (원본 설계 §13).
/// 화이트리스트는 반드시 `GameState.visible*(for:)`에서만 가져온다 — 존재하지 않는
/// 대상은 애초에 후보에 오르지 않는다.
public struct ActionResolver: Sendable {
    public init() {}

    public func resolve(_ intent: PlayerIntent, actor: EntityID, in state: GameState) -> ResolveResult {
        switch intent.kind {
        case .look:
            return .resolved(.observe(ObserveAction(actor: actor)))

        case .unknown:
            return .unsupported

        case .move:
            return resolve(intent.target, in: state.visibleConnections(for: actor)) { destination in
                .move(MoveAction(actor: actor, destination: destination))
            }

        case .talk:
            return resolve(intent.target, in: state.visibleNPCs(for: actor)) { target in
                .talk(TalkAction(actor: actor, target: target, message: intent.speech.isEmpty ? "Hello." : intent.speech))
            }

        case .attack:
            return resolve(intent.target, in: state.visibleNPCs(for: actor)) { target in
                .attack(AttackAction(attacker: actor, target: target, weapon: Self.defaultWeapon(for: actor, in: state)))
            }

        case .take:
            return resolve(intent.target, in: state.visibleGroundItems(for: actor)) { item in
                .takeItem(TakeItemAction(actor: actor, item: item))
            }

        case .use:
            let inventory = state.inventory(of: actor).reduce(into: [EntityID: String]()) { $0[$1.id] = $1.name }
            return resolve(intent.target, in: inventory) { item in
                .useItem(UseItemAction(actor: actor, item: item))
            }
        }
    }

    private func resolve(
        _ term: String,
        in catalog: [EntityID: String],
        build: (EntityID) -> GameAction
    ) -> ResolveResult {
        let candidates = EntityMatcher.match(term: term, in: catalog)
        switch candidates.count {
        case 0:
            return .notFound(term: term)
        case 1:
            return .resolved(build(candidates[0]))
        default:
            return .ambiguous(candidates: candidates)
        }
    }

    /// 무기를 명시적으로 고를 UI가 아직 없으므로(§40 2단계 범위), 인벤토리의 첫 무기를
    /// 자동으로 든다. 없으면 맨손(GameEngine 기본 d8)으로 처리된다.
    private static func defaultWeapon(for actor: EntityID, in state: GameState) -> EntityID? {
        state.inventory(of: actor).first { item in
            if case .weapon = item.effect { return true }
            return false
        }?.id
    }
}

/// 이름 카탈로그 안에서 자유 텍스트로 후보를 찾는다. 정확히 일치하는 이름이 있으면
/// 그것만 후보로 삼고, 없으면 부분 일치를 모두 후보로 남겨 모호성을 드러낸다.
enum EntityMatcher {
    static func match(term: String, in catalog: [EntityID: String]) -> [EntityID] {
        let needle = normalize(term)
        guard !needle.isEmpty else { return [] }

        let exact = catalog.filter { normalize($0.value) == needle }
        if !exact.isEmpty {
            return exact.keys.sorted { catalog[$0]! < catalog[$1]! }
        }

        let partial = catalog.filter {
            let name = normalize($0.value)
            return name.contains(needle) || needle.contains(name)
        }
        return partial.keys.sorted { catalog[$0]! < catalog[$1]! }
    }

    private static func normalize(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for article in ["the ", "a ", "an "] where result.hasPrefix(article) {
            result.removeFirst(article.count)
        }
        return result
    }
}
