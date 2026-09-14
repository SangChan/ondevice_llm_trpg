import FoundationModels

/// 요약 기반으로 롤링 교체되는 본 서사 세션 (수정 지침 §32). 세션은 동시 요청을 받지
/// 못하므로 actor로 소유한다 — 직렬화가 공짜로 딸려온다.
///
/// "대화가 너무 길어졌습니다"를 사용자에게 보여주는 것은 게임에서는 허용되지 않는
/// 실패다. `exceededContextWindowSize`는 반드시 내부에서 복구한다.
///
/// AI 계층(FoundationModels 세션 자체)은 실기기 하니스로 검증한다 — 이 타입에는
/// 자동 테스트가 없다(설계 §37 "AI 계층 | 골든 파일 + 실기기 하니스 | CI에 넣지 않는다").
public actor NarrationSessionManager: Narrating {
    private var session: LanguageModelSession
    private var summary: String
    private var turnsSinceReset: Int
    private let contextBuilder = ContextBuilder()

    public init(session: LanguageModelSession = LanguageModelSession(instructions: DMInstructions.text)) {
        self.session = session
        self.summary = ""
        self.turnsSinceReset = 0
    }

    public func narrate(_ context: NarrationContext) async throws -> String {
        do {
            return try await respond(context)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            rebuildSession()
            return try await respond(context)
        }
    }

    private func respond(_ context: NarrationContext) async throws -> String {
        let prompt = contextBuilder.buildNarrationPrompt(context)
        let response = try await session.respond(to: prompt)
        turnsSinceReset += 1
        // TODO(engineering): 지금은 요약을 만들지 않는다 — turnsSinceReset이 일정
        // 수치를 넘기면 지금까지의 narration을 요약해 `summary`에 채워 두는 로직이
        // 필요하다(§32 "요약 기반으로 롤링 교체"). exceededContextWindowSize가 실제로
        // 터진 뒤에야 재구성하는 지금 방식은 사전 예방이 아니라 사후 복구에 가깝다.
        return response.content
    }

    private func rebuildSession() {
        let instructions = summary.isEmpty
            ? DMInstructions.text
            : "\(DMInstructions.text)\n\nStory so far: \(summary)"
        session = LanguageModelSession(instructions: instructions)
        turnsSinceReset = 0
    }
}
