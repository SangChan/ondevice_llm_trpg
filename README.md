# ondevice_llm_trpg

On-device LLM 기반 1인용 TRPG. 규칙은 결정론, 표현은 생성.

- `Packages/`, `llm-trpg/` — iOS 26 앱. `GameCore`/`GameRules`/`GameAI` SPM 패키지 +
  SwiftUI 앱, Apple Foundation Models.
- `web/` — 같은 설계의 웹 포트. 규칙 엔진은 WebAssembly(AssemblyScript), DM은
  Transformers.js. 실행 방법은 [web/README.md](web/README.md).
- `docs/on-device-llm-trpg-design-addendum.md` — 설계 근거(플랫폼 제약, 모델 수정 지침).
- `improvements.md` — 단계별 "문제 → 해결 → 결과" 기록.
