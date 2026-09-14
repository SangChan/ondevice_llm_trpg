import GameCore

/// 수정 지침 §13-D — Resolver는 이 화이트리스트 안에서만 매칭한다.
/// "존재하지 않는 NPC hallucination"에 대한 유일하고 확실한 방어다. 프롬프트로
/// 부탁하는 방식은 방어가 아니다.
extension GameState {
    /// 같은 장소의 NPC. 죽은 NPC도 포함한다 — "쓰러진 고블린"처럼 여전히 지칭 가능한
    /// 대상이다. 생사 판정은 소비자(Resolver/GameEngine)의 몫이다.
    public func visibleNPCs(for actor: EntityID) -> [EntityID: String] {
        guard let location = actorLocation(actor) else { return [:] }
        return npcs.values
            .filter { $0.location == location }
            .reduce(into: [:]) { $0[$1.id] = $1.name }
    }

    /// 같은 장소 바닥의 아이템. `isHidden`인 아이템은 제외한다(§31-1).
    public func visibleGroundItems(for actor: EntityID) -> [EntityID: String] {
        guard let location = actorLocation(actor) else { return [:] }
        return items.values
            .filter { $0.placement == .location(location) && !$0.isHidden }
            .reduce(into: [:]) { $0[$1.id] = $1.name }
    }

    /// 현재 장소와 연결된 장소들.
    public func visibleConnections(for actor: EntityID) -> [EntityID: String] {
        guard let location = actorLocation(actor), let current = locations[location] else { return [:] }
        return current.connections.reduce(into: [:]) { partial, id in
            if let connected = locations[id] {
                partial[id] = connected.name
            }
        }
    }

    /// 같은 Location의 NPC + 바닥 아이템 + 연결된 Location 이름 (보강판 §13-D).
    public func visibleEntities(for actor: EntityID) -> [EntityID: String] {
        visibleNPCs(for: actor)
            .merging(visibleGroundItems(for: actor)) { existing, _ in existing }
            .merging(visibleConnections(for: actor)) { existing, _ in existing }
    }

    private func actorLocation(_ actor: EntityID) -> EntityID? {
        if actor == player.id { return player.location }
        return npcs[actor]?.location
    }
}
