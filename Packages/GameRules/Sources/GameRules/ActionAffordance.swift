import GameCore

/// 이미 EntityID까지 해석된 행동 버튼 (§31-1). 원천 데이터는 ActionResolver가 쓰는
/// 가시성 화이트리스트와 동일하다 — 새 데이터도, 새 저작물도 필요 없다.
public struct ActionAffordance: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let action: GameAction

    public init(id: String, label: String, action: GameAction) {
        self.id = id
        self.label = label
        self.action = action
    }
}

extension ActionAffordance: Hashable {
    public static func == (lhs: ActionAffordance, rhs: ActionAffordance) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension GameState {
    /// `actor`가 지금 할 수 있는 행동을 결정론적으로 나열한다. 순수 함수다 — LLM도
    /// UI도 모른다.
    public func affordances(for actor: EntityID) -> [ActionAffordance] {
        var result: [ActionAffordance] = [
            ActionAffordance(id: "look", label: "Look Around", action: .observe(ObserveAction(actor: actor)))
        ]

        for (id, name) in visibleConnections(for: actor).sorted(by: { $0.value < $1.value }) {
            result.append(ActionAffordance(
                id: "move:\(id.rawValue.uuidString)",
                label: "Go to \(name)",
                action: .move(MoveAction(actor: actor, destination: id))
            ))
        }

        for (id, name) in visibleNPCs(for: actor).sorted(by: { $0.value < $1.value }) {
            guard let npc = npcs[id], npc.stats.isAlive else { continue }

            result.append(ActionAffordance(
                id: "talk:\(id.rawValue.uuidString)",
                label: "Talk to \(name)",
                action: .talk(TalkAction(actor: actor, target: id, message: "Hello."))
            ))
            result.append(ActionAffordance(
                id: "attack:\(id.rawValue.uuidString)",
                label: "Attack \(name)",
                action: .attack(AttackAction(attacker: actor, target: id, weapon: nil))
            ))
        }

        for (id, name) in visibleGroundItems(for: actor).sorted(by: { $0.value < $1.value }) {
            result.append(ActionAffordance(
                id: "take:\(id.rawValue.uuidString)",
                label: "Take \(name)",
                action: .takeItem(TakeItemAction(actor: actor, item: id))
            ))
        }

        for item in inventory(of: actor) where Self.isConsumable(item.effect) {
            result.append(ActionAffordance(
                id: "use:\(item.id.rawValue.uuidString)",
                label: "Use \(item.name)",
                action: .useItem(UseItemAction(actor: actor, item: item.id))
            ))
        }

        return result
    }

    private static func isConsumable(_ effect: ItemEffect) -> Bool {
        if case .consumable = effect { return true }
        return false
    }
}
