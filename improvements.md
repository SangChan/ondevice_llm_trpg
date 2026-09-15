# improvements.md

이 문서는 PR 단위로 "문제 → 해결 → 결과"를 기록한다.
설계 근거는 `on-device-llm-trpg-design.md`(원본)와 `on-device-llm-trpg-design-addendum.md`(보강판)를 따른다.

---

## Phase 1 — GameCore (설계 §40 1단계, 항목 1~10)

### 문제

프로젝트가 SwiftData 템플릿 상태 그대로였고, 게임 규칙을 담을 GameCore가 없었다.
원본 설계(§4 Core Model)는 `Player`/`NPC`에 `armorClass`가 없어 공격 판정(§11)이
컴파일되지 않고, 아이템이 바닥/인벤토리/NPC 소지 중 어디에 있는지 표현할 방법이 없어
`takeItem`을 구현하는 순간 막히는 상태였다(보강판 수정 지침 A-2).
또한 `state.turn`이 `move`에만 있고 NPC가 행동하지 않아, 그대로 구현하면
"고블린이 가만히 맞다가 죽는 게임"이 된다(보강판 §35).

### 해결

- 보강판 수정 지침 A~C, §35를 반영해 `Stats`/`Combatant`/`ItemPlacement`/`ActionFailure`/
  `Dice`(SplitMix64 값 타입 + scripted)/`NPCBehavior`를 도입했다.
- `GameCore`를 별도 SPM 로컬 패키지(Foundation만 의존)로 분리했다. 폴더 분리만으로는
  "GameCore는 AI를 몰라야 한다"는 원본 §3 원칙이 강제되지 않으므로(설계 §37),
  타겟을 나눠 컴파일 경계를 만들었다. `GameRules`/`GameAI`도 같은 이유로 미리
  스캐폰딩만 해 두었다(내용은 Phase 2/3).
- `GameEngine`을 actor로 구현하고, 성공 + `turnCost == .full`인 행동만 `advanceWorld()`로
  세계를 전진시키도록 했다(보강판 §35 파이프라인). NPC의 행동 "선택"은
  `AggressiveBehavior`(결정론적 규칙)가 맡고, 대사는 이 단계에서 다루지 않는다
  (LLM은 Phase 3).
- `CombatMath.resolveAttack`을 만들어 플레이어→NPC 공격(`GameEngine.attack`)과
  NPC→플레이어 반격(`AggressiveBehavior.act`)이 같은 주사위·데미지 계산을 공유하게 했다.
  두 곳에 같은 로직을 복사하는 대신 즉시 공통화했다.
- Xcode 프로젝트에 세 패키지를 로컬 Swift Package Dependency로 연결했다. 설치된
  `xcodeproj` gem(1.23.0)이 Xcode 16+ 파일시스템 동기화 그룹(`PBXFileSystemSynchronizedRootGroup`)
  포맷을 파싱하지 못해 프로젝트를 깨뜨렸으므로, `project.pbxproj`를 직접 수정하는
  방식으로 전환했다(대안 검토 및 미채택 사유).

### 결과

- 이전: LLM 없이는 아무 것도 실행할 수 없는 SwiftData 템플릿.
- 이후: `GameCore` 단위 테스트 30개(이동/관찰/대화/전투/아이템/NPC 반격/결정론적
  리플레이) 전부 통과, `swift-tools-version: 6.2` 기준 `GameCore`/`GameRules`/`GameAI`
  세 패키지 모두 독립 빌드 성공, `xcodebuild -scheme llm-trpg -destination 'generic/platform=iOS Simulator' build`
  전체 앱 빌드 성공(패키지 그래프 resolve 포함)을 확인했다.
- 아직 없음: `ActionResolver`/행동 칩/`ScenarioNarrator`/LLM 연동 — 설계 §40의
  2단계(Classic Mode)·3단계(AI Mode)에서 이어진다.

---

## Phase 2 — Classic Mode (설계 §40 2단계, 항목 11~17)

### 문제

GameCore만으로는 플레이할 방법이 없었다 — 자연어를 GameAction으로 바꿀 파서도,
대상 문자열을 EntityID로 바꿀 Resolver도, 사건을 문장으로 바꿀 narrator도, 화면도
없었다. LLM 없이 완결된 게임이 §40의 목표였는데, 그 전제가 되는 레이어 전체가
비어 있었다.

### 해결

- `PlayerIntent`/`ActionResolver`/`ResolveResult`/`GameState.visible*(for:)`/
  `ActionAffordance`를 `GameRules`에 추가했다(수정 지침 §13-D, §31-1). Resolver는
  반드시 가시성 화이트리스트 안에서만 매칭하게 했다 — 존재하지 않는 대상에 대한
  유일한 방어다.
- `IntentParsing`/`Narrating` 프로토콜과 그 첫 구현체(`KeywordIntentParser`,
  `TemplateNarrator`, `ScenarioNarrator`)를 `GameAI`에 추가했다(설계 §29). `GameAI`가
  `GameRules`에 의존하도록 `Package.swift`를 갱신했다 — `PlayerIntent`를 만드는 쪽
  (파서)과 소비하는 쪽(Resolver)이 같은 타입을 봐야 했기 때문이다.
- 데미지 수치·주사위 눈은 어떤 narrator도 문장에 넣지 않는다(§36) — 숫자는 UI 몫,
  서사는 narrator 몫이라는 경계를 코드로 강제했다.
- `ScenarioNarrator`는 시나리오에 적힌 사건만 작가의 문장을 쓰고, 나머지는
  `TemplateNarrator`로 흘려보낸다(§31 "1층/2층"). `ScenarioCondition`은 스키마
  4종(`always`/`firstMeeting`/`hostile`/`friendly`)을 다 만들어 두되, 실제 선택 로직은
  `.always`만 구현했다 — 나머지는 "이미 만난 적 있는가" 같은 상태 추적이 있어야
  의미가 생기는데, 그 추적(§16 NPC Memory)은 5단계다. 지금 동작하지 않는 조건을
  구현한 것처럼 보이지 않도록 이 파일에 명시해 둔다.
- Forest Clearing–Dark Cave–Old Shrine 3개 장소, NPC 3명(Old Hunter/Goblin
  Scout/Shrine Keeper)짜리 초안 시나리오를 `DefaultScenarioRepository`에 작성했다.
  최종 분량·문장은 보강판 §41 미결 사항 1번대로 아직 확정이 아니다.
- SwiftData 템플릿(`Item.swift`, `ContentView.swift`, `ModelContainer`)을 걷어내고
  `Features/Game/{Repository,ViewModel,Views}` + `Core/Resources/AppResources.swift`로
  교체했다. Repository/Engine/Parser/Narrator 생성은 `llm_trpgApp`(Composition Root)
  한 곳에서만 한다 — View는 `GameViewModel`만 안다.
- `GameViewModel`은 `@Observable`(iOS 26 타깃이라 조건 없이 사용 가능)이고, §34의
  실패 분류(파싱 실패/ambiguous/notFound/unsupported)를 전부 여기서 흡수한다 —
  어떤 경우도 에러 다이얼로그가 되지 않는다.

### 결과

- 이전: GameCore만 있고 실행 가능한 게임은 없었다.
- 이후: `GameRules` 24개·`GameAI` 16개 단위 테스트(총 GameCore 포함 70개) 전부 통과.
  `xcodebuild ... build`로 전체 앱 빌드 성공, 실제 iPhone 17 Pro 시뮬레이터에서
  `xcodebuild test`(런치 테스트 포함) 통과, 시뮬레이터 스크린샷으로 시작 장소 묘사·
  입력창·Send 버튼·칩 바 토글이 실제로 렌더링되는 것을 육안으로 확인했다.
  **LLM 없이, 이 시점부터 처음부터 끝까지 플레이 가능한 게임이 존재한다** — §40이
  2단계 종료 시점의 목표로 못 박은 지점이다.
- 아직 없음: 저장/불러오기(4단계), 신고 UI·연령 등급(4단계), AI Mode 전체(3단계).
  칩 UI는 자동화 테스트로 탭까지 확인하지 못했다(시뮬레이터 스크린샷으로 렌더링만
  확인) — Phase 3에서 UIHostingController 기반 테스트를 붙일 때(체크리스트 §7)
  같이 보강한다.

---

## Phase 2 보강 — 시나리오에 목표·결말 부여

### 문제

"2단계 종료 시점에 이미 출시 가능한 게임이 존재한다"고 보고했지만, 실제 콘텐츠는
장소 묘사 3줄 + NPC 인사말 1줄씩 + 사망 대체문 1개뿐이었다. 목표도 결말도 없어서
왜 동굴에 가는지, 뭘 하면 끝나는지 알 수 없는 샌드박스였다 — "게임이 존재한다"는
표현이 이 공백을 가렸다. 사용자가 직접 확인하고 지적했다.

### 해결

- 지금 엔진이 실제로 처리하는 두 경로(`ScenarioScript.npcLines`의 `.always` 대사,
  `eventOverrides`의 `.npcDefeated` 대체문)만으로 목표→갈등→결말이 있는 최소 아크를
  썼다: Old Hunter가 고블린 처치를 부탁 → 고블린 처치 시 결말성 문장 출력.
  지원되지 않는 조건(퀘스트 완료 후 대사 변경, Shrine Keeper의 역할)은 **쓰지 않고**
  `// TODO(scenario):`/`// TODO(engineering):`으로 남겼다 — Xcode 점프 바에서 바로
  보이도록 실제 TODO 태그 문법을 썼다.
- "안 되는 걸 되는 것처럼" 보이지 않도록, `ScenarioNarrator.scriptedLine(for:)`
  쪽에도 대칭되는 TODO를 남겨 콘텐츠 파일과 엔진 파일 양쪽에서 같은 공백이 보이게
  했다.

### 결과

- 이전: 목표·결말 없는 샌드박스, 기능은 있으나 "게임"이라 부르기엔 부족.
- 이후: Old Hunter의 브리핑 → 고블린 처치 → 결말 문장으로 이어지는 최소 아크 존재.
  `firstMeeting`/`hostile`/`friendly` 조건별 대사, 퀘스트 완료 후 NPC 반응 변화,
  Shrine Keeper의 역할은 여전히 없음 — 코드 세 곳(`ScenarioRepository.swift` 헤더,
  `npcLines`/`eventOverrides` 인라인, `ScenarioNarrator.swift`)에 TODO로 명시.
  `swift test`(GameAI 16개) 및 전체 앱 빌드 재확인 통과.

---

## Phase 3 — AI Mode (설계 §40 3단계, 항목 18~24)

### 문제

Classic Mode(2단계)는 완결돼 있었지만 LLM이 전혀 얹혀 있지 않았다. `availability`
분기, guided generation, guardrail/컨텍스트 초과 복구, 세션 관리 중 아무것도 없었다.

### 해결

- `PlayMode.resolve(from:)`(§31), `ContextBuilder`(+`TokenBudget`/`TokenEstimator`,
  §36), `ParsedIntent`(`@Generable`)+`FoundationModelsIntentParser`(§30),
  `NarrationSessionManager`(§32), `ChainedIntentParser`/`ResilientNarrator`(§29,
  §33)를 `GameAI`에 추가했다. 실제 API 시그니처(`LanguageModelSession.respond(to:generating:)`,
  `GenerationError` 케이스 등)는 추측하지 않고 이 Mac(Xcode 26.6, macOS 26 SDK)에서
  스크래치 패키지로 직접 컴파일해 확인한 뒤 옮겨 적었다 — 전부 문서 예시와 정확히 일치했다.
- `GameAI`의 macOS 최소 버전을 `.v15`→`.v26`으로 올렸다 — `import FoundationModels`가
  `.v15`에서는 아예 존재하지 않는다는 걸 빌드해서 확인했다.
- `NarrationSessionManager`가 실제로 `Narrating`의 "FoundationModelsNarrator" 역할을
  겸한다 — 설계 §29 표는 별도 타입처럼 그리지만, §32의 실제 코드가 이미
  `Narrating` 시그니처와 같아서 별도 wrapper를 만들면 순수 중복이 된다. `RecordingNarrator`
  (골든 파일 녹화용)는 Phase 3 항목 18~24에 없어 이번엔 만들지 않았다.
- App 레이어: `PlayMode`에 따라 Composition Root가 parser/narrator 조합을 바꾼다.
  `.userChoice`(설정에서 Classic 강제)는 재시작이 있어야 반영된다 — 세션 중간에
  `LanguageModelSession`/actor를 안전하게 바꿔 끼우는 로직은 만들지 않았다(TODO로 명시).
  `GameViewModel.isThinking`으로 동시 요청 중 입력을 잠근다(§34).

### 발견한 버그 — FoundationModels 호출이 무기한 멈출 수 있다

빌드는 전부 성공했지만 시뮬레이터에서 실행하니 시작 서사가 영원히 안 나왔다.
`os.Logger`로 추적한 결과: 시뮬레이터의 `SystemLanguageModel.default.availability`가
`.available`을 보고했고(AI Mode로 분기), 실제 `session.respond(to:)` 호출이 **throw도
return도 없이 그냥 멈췄다.** `ResilientNarrator`는 catch로만 폴백하므로 애초에
에러가 안 나면 폴백이 작동하지 않는다 — 게임이 "절대 멈추지 않는다"는 원칙(§29, §33)이
실제로 깨지는 경로였다.

**해결**: `AITimeout.swift`(`withAITimeout`)로 `ResilientNarrator.primary`와
`ChainedIntentParser.fallback` 호출에 각각 12초/8초 상한을 걸었다. 둘 다 설계
문서에 없는 임의값이다 — 실기기 체감 지연을 보고 나중에 조정해야 한다. 타임아웃도
결국 `catch`로 들어오므로 기존 폴백 경로를 그대로 탄다. 짧은 타임아웃(0.05초)으로
행 테스트 2개를 추가해 실제로 재현·고정했다.

이 버그는 addendum이 이미 "시뮬레이터 신뢰 불가"(§33)라고 경고한 지점과 정확히
겹친다 — 다만 그 경고는 "guardrail 통과율 측정에 시뮬레이터를 쓰지 마라"는
맥락이었지, "시뮬레이터가 무기한 행을 유발할 수 있다"까지는 명시하지 않았었다.
타임아웃 보호가 없었다면 실기기에서도 동일한 클래스의 문제(네트워크 없는 순수
온디바이스 모델이라도 첫 로딩·다운로드 대기 중 유사 지연 가능성)가 게임을 완전히
멈출 수 있었다 — 그래서 이건 "시뮬레이터 한정 워크어라운드"가 아니라 구조적 수정으로
넣었다.

### 결과

- 이전: LLM이 없었다. Classic Mode만 존재.
- 이후: `GameAI` 31개 단위 테스트(총 GameCore 30 + GameRules 24 + GameAI 31 = 85개)
  전부 통과. 전체 앱 빌드 성공(clean build로 재확인). 시뮬레이터에서 실제 실행 →
  AI Mode로 분기 → primary(FoundationModels) 타임아웃 → fallback(ScenarioNarrator)
  으로 정상적으로 시작 서사가 나오는 것까지 스크린샷으로 확인했다.
- 자동 테스트가 없는 부분(설계 §37 원칙대로 의도적): `FoundationModelsIntentParser.parse`/
  `NarrationSessionManager` 자체의 실제 생성 결과 — 실기기 하니스·골든 파일 몫이다.
  0주차 guardrail Spike도 여전히 미실행.
- 남은 TODO: 세션 요약 기반 사전 예방(`turnsSinceReset`은 있지만 요약을 만들지 않음),
  guardrail/타임아웃 발생률 메트릭 누적, `.userChoice` 재시작 없는 라이브 전환,
  `RecordingNarrator`.

---

## Web Port — WASM 규칙 엔진 + Transformers.js (`web/`)

설계 §40의 단계(iOS)와는 별개 트랙이다. iOS 앱은 그대로 두고, 같은 설계를 브라우저에서
증명한다.

### 문제

이 프로젝트의 주장("규칙은 결정론, 표현은 생성, 표현은 실패해도 게임은 멈추지 않는다")은
Apple Foundation Models와 iOS 26 기기가 있어야만 확인할 수 있었다. 설계의 핵심이
플랫폼이 아니라 경계에 있다면, 런타임을 갈아끼워도 같은 게임이 나와야 한다.

### 해결

- `Packages/GameCore` + `Packages/GameRules`를 AssemblyScript로 포팅해 WASM 하나로
  컴파일했다(`web/assembly/index.ts` → `build/game_core.wasm`, 약 30KB). 폴더가 아니라
  **모듈 경계**가 원칙을 강제한다는 점은 SPM 타겟 분리와 같다 — JS는 `execute`/`snapshot`/
  `affordances` 말고는 세계에 접근할 방법이 없다.
- LLM 자리에 Transformers.js(SmolLM2 135M/360M, Qwen2.5 0.5B, ONNX q4)를 넣고 워커에서
  돌린다. 백엔드 기본값은 WebAssembly, WebGPU는 선택이다.
- `KeywordIntentParser`/`ChainedIntentParser`/`ActionResolver`/`TemplateNarrator`/
  `ScenarioNarrator`/`ResilientNarrator`/`ContextBuilder`/`DMInstructions`를 같은 이름·같은
  경계로 옮겼다. 자유 입력은 여전히 가시성 화이트리스트 안에서만 EntityID가 된다.
- iOS와 의도적으로 다른 점 3가지:
  1. `EntityID`가 UUID 대신 순증 i32다(불투명 핸들이라는 성질은 동일).
  2. 실패한 행동에 `actionRejected` 이벤트를 하나 실어 보낸다. Swift 엔진은 빈 배열을
     돌려주는데, 그러면 narrator가 "Nothing happens."만 말한다.
  3. narrator를 3층으로 쌓았다 — 작가의 문장이 있는 사건은 그대로 쓰고, 나머지만 LLM이
     쓰고, LLM이 실패하면 템플릿이 받는다. 브라우저에서 돌릴 수 있는 크기의 모델에게
     장소 묘사까지 맡기면 작가의 문장만 잃는다.
- 실측에서 135M 모델이 `[HP 30/20]` 같은 수치를 지어냈다. 고쳐 쓰지 않고 **실패로
  취급**한다(`usableNarration`: 숫자 포함·프롬프트 반향·미완성 문장 → throw →
  `ResilientNarrator`가 작가의 문장으로 대체). 잘못된 서사보다 정확한 시나리오 문장이 낫다.

### 실제로 띄워 보고 고친 것

- **`hidden` 속성이 먹지 않았다.** `.settings`/`.chips-list`에 `display: flex`를 주는 순간
  작성자 스타일이 UA의 `[hidden] { display: none }`을 이긴다. Settings 패널이 첫 화면부터
  게임을 덮고 있었고 Done을 눌러도 닫히지 않았다. `[hidden] { display: none !important }`
  한 줄로 해결.
- **같은 모델을 동시에 두 번 내려받을 수 있었다.** 모드 라디오와 Load 버튼이 둘 다
  `load()`를 부르는데 워커가 메시지를 직렬화하지 않아 `pipeline()`이 두 번 시작되고,
  먼저 건 promise는 영영 풀리지 않았다(= "다운로드가 멈춤"). 같은 요청은 같은 promise로
  합류시키고 워커 메시지를 직렬 처리한다. 회귀 테스트 2개 추가.
- **모델 로딩 표시가 거짓말을 했다.** 파일별 퍼센트만 보여줘서 40초짜리 단일 파일이
  멈춘 것처럼 보이고, 다운로드 뒤 세션 생성 구간에는 이벤트가 0개라 완전히 정지한 것처럼
  보였다. 바이트 합산 막대 + 불확정 애니메이션 + 경과 초 + 20초 무응답 시 안내로 바꿨다.
- **LLM 문장이 끝에서 잘렸다.** 원인이 두 개였다. (1) `max_new_tokens=72`가 두 번째
  문장 중간에서 생성을 끊었다. (2) 화면에는 모델 출력을 날것으로 흘려보내 놓고 최종본은
  2문장으로 다듬어서, 방금 읽던 문장이 사라졌다. 필요한 문장 수를 채우면
  `InterruptableStoppingCriteria`로 생성을 멈추고(천장은 128로 올림), 스트리밍과
  최종본이 `narrationText()` 하나를 공유하게 했다. 숫자가 섞였을 때도 서사 전체가 아니라
  그 문장만 버린다 — 3문장 중 하나 때문에 나머지를 잃을 이유가 없다.
- **서사 스트리밍이 떨렸다.** 토큰마다 트랜스크립트를 통째로 다시 만들어 모든 말풍선의
  등장 애니메이션이 매번 재생됐다. 노드를 id로 재사용하고, 갱신을 50ms로 묶고,
  `scroll-behavior: smooth`를 뺐다(매 토큰 스크롤 목표가 갱신되며 출렁였다).
  `requestAnimationFrame`으로 묶는 방식은 쓰지 않았다 — 배경 탭에서 멈춘다.

### 결과

- `npm test` 35개 통과: WASM 엔진 13개(이동/관찰/전투/반격/아이템/실패/행동 칩/시드
  리플레이) + 파서·Resolver·narrator·LLM 클라이언트 22개. 모델 다운로드 없이 돈다.
- 헤드리스 Chrome에서 실제 UI를 iframe으로 띄워 구동 확인: 설정 열고 닫기, 행동 칩 탭,
  자유 입력 → WASM 판정 → NPC 반격(HP 18/20, turn 2) → 칩 갱신까지 정상. AI Mode는
  SmolLM2-360M q4 기준 다운로드 41초 + 세션 생성 1.2초 후 4턴 플레이 확인.
- 아직 없는 것: 세이브/로드(리플레이 전제는 갖췄지만 상태를 내보내는 경로 없음),
  NPC 기억(`ScenarioCondition`은 `always`만 선택 — iOS와 동일), COOP/COEP 미설정이라
  onnxruntime은 단일 스레드 wasm으로 돈다.
