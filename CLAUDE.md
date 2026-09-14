# on-device-llm-trpg

On-device LLM(Apple Foundation Models) 기반 1인용 TRPG. 상위 `CLAUDE.md`(범용 iOS 하네스)는
여전히 기본값이지만, 아래 항목은 **이 프로젝트에서 명시적으로 다르며 우선한다.**

**구조적 결정을 내리기 전에 반드시 `docs/on-device-llm-trpg-design-addendum.md`를 참조한다.**
이 프로젝트의 설계 근거(플랫폼 제약, 모델 수정 지침, §29~42)가 전부 여기 있다 — 아래 항목들은
그 문서의 요약이지 대체가 아니다. 원본 `on-device-llm-trpg-design.md`(§1~28, addendum이
패치하는 대상)는 아직 저장소 밖에 있다 — addendum만 읽고 판단이 서지 않으면 원본도 `docs/`로
옮겨 받는다.

## 핵심 철학

> Rules are deterministic. Expression is generative. Expression may fail. The game must not.

LLM은 DM/Narrator/Intent Interpreter이지 Game Engine이 아니다. HP·데미지·아이템·NPC 생사·월드
상태는 오직 `GameEngine`(actor)만 바꾼다. LLM은 무엇을 원하는지 해석하고, 어떻게 이야기할지만
담당한다.

## 모듈 경계 (컴파일로 강제)

```
Packages/GameCore   — Foundation만 의존. 규칙·상태의 단일 소스. AI/UI를 몰라야 한다.
Packages/GameRules  — GameCore 의존. ActionResolver, 행동 칩(affordances).
Packages/GameAI     — GameCore 의존 + FoundationModels. IntentParsing/Narrating.
```

폴더 분리가 아니라 **SPM 타겟 분리**로 원칙을 강제한다 — `GameCore`에서
`import FoundationModels`를 쓰면 컴파일 에러가 나야 한다. 새 로직을 넣을 때 이 방향을
거스르지 않는지 먼저 확인한다(`GameCore`가 `GameRules`/`GameAI`를 의존해서는 절대 안 됨).

`swift-tools-version: 6.2` 필수 — `.iOS(.v26)` 플랫폼 상수가 6.2부터 존재한다(6.0/6.1은 컴파일 에러).

## 플랫폼 하드 제약 (취향이 아니라 사실)

- 컨텍스트 윈도우 = 세션당 4096 토큰. 히스토리를 무한히 쌓는 설계는 성립하지 않는다.
- guardrail은 override 불가. 전투 narration이 거부될 수 있다 — 항상 템플릿/시나리오로 폴백.
- 기기 제한(`UIRequiredDeviceCapabilities`) 사용 안 함, 최소 iOS/iPadOS 26. Apple Intelligence
  미지원 기기는 **Classic Mode로 게임 전체를 플레이한다** — 이것은 폴백이 아니라 제품의 두
  모드 중 하나다. `GameCore`/규칙/세이브는 두 모드에서 완전히 동일해야 한다.
- 세션은 동시 요청을 못 받는다. 한 턴의 LLM 호출은 직렬이다.

## 턴 모델

`GameAction.turnCost`가 `.full`이고 실행이 성공했을 때만 `GameEngine`이 `advanceWorld()`를
호출해 턴을 전진시키고 적대 NPC를 행동시킨다. 실패는 게임 시간을 소비하지 않는다. NPC의
행동 *선택*은 결정론적 규칙(`NPCBehavior`)이고, NPC의 *대사*만 LLM이 만든다 — 이 경계를
섞지 않는다.

## 결정론

`Dice`는 시드 RNG를 값 타입으로 소유하고 `Codable`이다(세이브 = 리플레이 전제). 딕셔너리
순회 결과를 노출하는 모든 곳(`inventory(of:)`, `advanceWorld`의 NPC 순서 등)은 반드시
정렬한다 — 정렬을 빼먹으면 스냅샷 테스트가 무작위로 실패한다.

## 실패는 에러 다이얼로그가 되지 않는다

AI 계층의 모든 실패(파싱 실패, 모호한 대상, guardrail 거부, 컨텍스트 초과)는 DM의 말이거나
보이지 않는 내부 복구다. 게임 상태는 이미 엔진이 확정했으므로 narration 실패가 진행을 막아선
안 된다.

## 언어 정책

게임 월드(narration, NPC 대사, 엔티티 이름, LLM instructions)는 **영어**. 앱 UI 크롬(설정,
버튼, 에러 메시지)만 로컬라이즈 대상. `ContextBuilder`에 언어 의존 문자열을 하드코딩하지 않는다.

## 테스트 — 상위 문서 대신 이것을 따른다

**Swift Testing(`@Test`)을 쓴다. XCTest·한국어 BDD 메서드명 규칙은 이 프로젝트에 적용하지
않는다.** 설명은 영어 문장으로: `@Test("moving through a connection succeeds")`. 각
패키지는 `swift test`로 독립 검증 가능해야 한다(LLM 의존 없이). AI 계층(FoundationModels)은
골든 파일 + 실기기 하니스로 다루고 일반 CI에는 넣지 않는다.

## 빌드 검증

`Packages/<Name>` 각각에서 `swift test`. 전체 앱은
`xcodebuild -project llm-trpg/llm-trpg.xcodeproj -scheme llm-trpg -destination 'generic/platform=iOS Simulator' build`
로 패키지 그래프 resolve까지 확인한다.

## 진행 순서

설계 문서 §40 "수정된 구현 순서"를 따른다: GameCore(완결) → Classic Mode(LLM 없이 출시
가능) → AI Mode(레이어로 얹음) → 출시 준비. 각 단계 종료 시점에 이전 단계는 그대로
동작해야 한다 — 나중 단계가 앞 단계를 깨뜨리면 순서의 의미가 없다.
