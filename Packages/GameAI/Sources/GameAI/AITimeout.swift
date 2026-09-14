/// FoundationModels 호출에 상한을 둔다.
///
/// 시뮬레이터에서 실제로 관찰된 문제: `SystemLanguageModel.default.availability`가
/// `.available`을 보고해도(§33 "시뮬레이터 신뢰 불가" — addendum이 이미 경고한 지점),
/// 실제 `session.respond(to:)` 호출이 throw도, 리턴도 없이 그냥 영원히 멈출 수 있다.
/// 이런 무한 대기는 `ResilientNarrator`/`ChainedIntentParser`의 catch를 트리거하지
/// 못하므로 — 게임이 "절대 멈추지 않는다"는 원칙(§29, §33)이 깨진다. 반드시 여기서
/// 타임아웃을 걸어 실패로 전환해야 폴백이 작동한다.
enum AITimeoutError: Error, Sendable {
    case timedOut
}

func withAITimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AITimeoutError.timedOut
        }
        defer { group.cancelAll() }
        // 두 태스크 중 먼저 끝나는 쪽의 결과(혹은 에러)를 받는다. 정상 종료 시
        // defer가 남은 태스크(타이머 또는 아직 도는 operation)를 취소한다.
        return try await group.next()!
    }
}
