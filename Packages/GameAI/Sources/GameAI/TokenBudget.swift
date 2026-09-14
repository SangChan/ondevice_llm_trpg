/// 세션당 4096 토큰이 하드 제약이다(§32). 예산을 상수화해 두면
/// `exceededContextWindowSize`를 "가끔 나는 에러"가 아니라 예방 가능한 것으로 다룰 수 있다.
public enum TokenBudget: Sendable {
    public static let window = 4096

    public enum Narration: Sendable {
        public static let instructions = 350
        public static let worldState = 500
        public static let recentEvents = 450
        public static let history = 900
        public static let response = 500
        /// 토큰 추정은 정확할 수 없으므로 반드시 남긴다.
        public static let headroom = 400
    }
}

/// 정확한 토크나이저가 없으므로 대략치만 낸다. 영어 기준 3~4글자 ≈ 1토큰(§0-1)이라는
/// 가정에 의존한다 — 한국어 게임 월드 지원(Phase 3 이후 착수 예정) 시점에 이 추정
/// 자체가 깨지므로 §32 토큰 예산과 함께 재설계해야 한다.
public enum TokenEstimator: Sendable {
    public static func estimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}
