/// primary(FoundationModels)가 어떤 이유로든 실패하면(guardrail 거부, 컨텍스트 초과
/// 복구 실패, 기타 throw) fallback(Classic Mode narrator)으로 조용히 넘어간다
/// (설계 §29, 수정 지침 §33). 게임 상태는 이미 엔진이 확정했으므로 narration 실패가
/// 게임 진행을 막아서는 안 된다 — 사용자에게 "차단되었습니다"를 노출하지 않는다.
public struct ResilientNarrator: Narrating {
    public let primary: any Narrating
    public let fallback: any Narrating
    private let timeoutSeconds: Double

    /// 12초는 설계 문서에 없는 임의값이다 — DM 응답을 기다리는 UX 상한선으로 판단해
    /// 정했다. guardrail Spike(0주차) 이후 실제 체감 지연을 보고 조정해야 한다.
    public init(primary: any Narrating, fallback: any Narrating, timeoutSeconds: Double = 12) {
        self.primary = primary
        self.fallback = fallback
        self.timeoutSeconds = timeoutSeconds
    }

    public func narrate(_ context: NarrationContext) async throws -> String {
        do {
            return try await withAITimeout(seconds: timeoutSeconds) {
                try await primary.narrate(context)
            }
        } catch {
            // TODO(engineering): §33 "발생률을 로컬 메트릭으로 누적해 OS 업데이트 후
            // 회귀를 감지한다" — 지금은 폴백만 하고 어떤 이유로 실패했는지(guardrail인지,
            // 타임아웃인지, exceededContextWindowSize 복구 실패인지) 기록하지 않는다.
            return try await fallback.narrate(context)
        }
    }
}
