import GameCore

extension GameState {
    /// 칩을 탭해도 플레이어가 직접 입력한 것처럼 영어 문장으로 트랜스크립트에 기록한다
    /// (§31-1 "트랜스크립트 일관성"). 자유 입력은 이미 문장이므로 이 함수를 거치지 않는다.
    public func playerSentence(for action: GameAction) -> String {
        switch action {
        case .move(let a):
            return "You go to \(locations[a.destination]?.name ?? "the other side")."
        case .observe:
            return "You look around."
        case .talk(let a):
            return "You talk to \(npcs[a.target]?.name ?? "them")."
        case .attack(let a):
            return "You attack \(npcs[a.target]?.name ?? "them")."
        case .takeItem(let a):
            return "You take the \(items[a.item]?.name ?? "item")."
        case .useItem(let a):
            return "You use the \(items[a.item]?.name ?? "item")."
        }
    }
}
