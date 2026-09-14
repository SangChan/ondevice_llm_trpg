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
