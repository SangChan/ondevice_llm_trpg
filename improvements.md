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
