/// SplitMix64 — 결정론적이고 `Codable`한 시드 기반 RNG.
/// `GameEngine`이 `Dice`를 값 타입으로 소유하므로 락도 actor도 필요 없다
/// (수정 지침 C).
public struct SplitMix64: RandomNumberGenerator, Codable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public enum RollKind: String, Codable, Sendable, Equatable {
    case attack
    case damage
    case skill
}

/// 시드 RNG + 테스트용 스크립트 굴림을 함께 갖는 값 타입.
/// `Codable`이므로 세이브 시점의 RNG 상태가 그대로 저장되고,
/// 로드 후에도 동일한 굴림 시퀀스가 이어진다 (§38 리플레이의 전제).
public struct Dice: Sendable, Codable {
    private var rng: SplitMix64
    private var scripted: [Int]
    private var cursor: Int = 0

    public init(seed: UInt64) {
        self.rng = SplitMix64(seed: seed)
        self.scripted = []
    }

    /// 테스트용 — 정해진 값을 순서대로 반환하고, 소진되면 시드 RNG로 넘어간다.
    public init(scripted: [Int], seed: UInt64 = 0) {
        self.rng = SplitMix64(seed: seed)
        self.scripted = scripted
    }

    public mutating func roll(_ kind: RollKind, sides: Int) -> Int {
        if cursor < scripted.count {
            defer { cursor += 1 }
            return scripted[cursor]
        }
        return Int.random(in: 1...sides, using: &rng)
    }
}
