/// 행동이 게임 턴을 소비하는지 여부 (수정 지침 §35).
/// `observe`만 `free` — 둘러본 것만으로 적에게 맞으면 탐색이 빈곤해진다.
public enum TurnCost: Sendable, Equatable {
    case free
    case full
}

public struct MoveAction: Sendable, Equatable {
    public let actor: EntityID
    public let destination: EntityID

    public init(actor: EntityID, destination: EntityID) {
        self.actor = actor
        self.destination = destination
    }
}

public struct ObserveAction: Sendable, Equatable {
    public let actor: EntityID

    public init(actor: EntityID) {
        self.actor = actor
    }
}

public struct TalkAction: Sendable, Equatable {
    public let actor: EntityID
    public let target: EntityID
    public let message: String

    public init(actor: EntityID, target: EntityID, message: String) {
        self.actor = actor
        self.target = target
        self.message = message
    }
}

public struct AttackAction: Sendable, Equatable {
    public let attacker: EntityID
    public let target: EntityID
    public let weapon: EntityID?

    public init(attacker: EntityID, target: EntityID, weapon: EntityID? = nil) {
        self.attacker = attacker
        self.target = target
        self.weapon = weapon
    }
}

public struct TakeItemAction: Sendable, Equatable {
    public let actor: EntityID
    public let item: EntityID

    public init(actor: EntityID, item: EntityID) {
        self.actor = actor
        self.item = item
    }
}

public struct UseItemAction: Sendable, Equatable {
    public let actor: EntityID
    public let item: EntityID
    public let target: EntityID?

    public init(actor: EntityID, item: EntityID, target: EntityID? = nil) {
        self.actor = actor
        self.item = item
        self.target = target
    }
}

/// 실행할 명령. 결과를 표현하지 않는다 — 결과는 `ActionResult`/`GameEvent`의 몫이다
/// (원본 설계 §5).
public enum GameAction: Sendable, Equatable {
    case move(MoveAction)
    case observe(ObserveAction)
    case talk(TalkAction)
    case attack(AttackAction)
    case takeItem(TakeItemAction)
    case useItem(UseItemAction)

    public var turnCost: TurnCost {
        switch self {
        case .observe:
            return .free
        case .move, .talk, .attack, .takeItem, .useItem:
            return .full
        }
    }
}
