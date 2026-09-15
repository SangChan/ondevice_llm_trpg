# on-device-llm-trpg — Web

iOS 앱(`Packages/GameCore` + `GameRules` + `GameAI`)과 같은 설계를 브라우저로 옮긴 판.
Apple Foundation Models 자리에 **Transformers.js**가, Swift 패키지 자리에 **WebAssembly**가 들어간다.

> Rules are deterministic. Expression is generative. Expression may fail. The game must not.

- **규칙과 상태는 WASM 안에만 있다.** `assembly/index.ts`(AssemblyScript → `build/game_core.wasm`)가
  HP·데미지·아이템·NPC 생사·턴을 독점한다. JS는 이미 EntityID까지 해석된 행동을 넘기고 결과
  이벤트를 읽을 뿐이다.
- **LLM은 DM/Narrator/Intent Interpreter다.** Transformers.js가 하는 일은 (1) 사건을 문장으로
  옮기고 (2) 키워드 파서가 포기한 자유 입력을 의도로 바꾸는 것뿐이다. 프롬프트 인젝션이
  성공해도 HP는 1도 바뀌지 않는다 — 방어의 본체가 프롬프트가 아니라 구조이기 때문이다.
- **모델이 없어도 게임은 끝까지 플레이된다.** Classic Mode는 폴백이 아니라 두 모드 중 하나다.

## 실행

```bash
cd web
npm install
npm start          # WASM 빌드 + http://localhost:4173
```

`npm test` — WASM 규칙 엔진 + 파서/Resolver/narrator 테스트 35개 (모델 다운로드 없음).

첫 화면은 Classic Mode다. Settings → Model → **Load model** 을 누르면 Hugging Face Hub에서
모델을 받아(브라우저 캐시에 저장) AI Mode로 전환된다. 기본 백엔드는 WebAssembly이고,
WebGPU를 지원하는 브라우저에서는 선택할 수 있다.

모델 로딩은 두 단계다. **다운로드**(막대가 MB 단위로 찬다)가 끝난 뒤에도 **세션 생성**
단계가 남아 있는데, 이 구간에는 진행 이벤트가 하나도 오지 않는다 — 막대가 불확정 애니메이션으로
바뀌고 경과 초만 올라간다. 멈춘 것이 아니다. 실측(로컬 캐시 없음, 6MB/s): 360M 기준 다운로드
41초 + 세션 생성 1.2초.

| 모델 | 크기(q4) | 성격 |
| --- | --- | --- |
| SmolLM2-135M-Instruct | ~100MB | 가장 빠름. 문장이 단순하다. |
| SmolLM2-360M-Instruct | ~250MB | 기본값. 속도/문장 균형. |
| Qwen2.5-0.5B-Instruct | ~400MB | 문장이 가장 낫다. wasm에서는 느리다. |

## 배포

정적 파일뿐이라 서버가 필요 없다. 경로는 전부 상대 경로라 `/<repo>/` 같은 서브패스에서도
그대로 동작한다.

**GitHub Pages** — `.github/workflows/deploy-web.yml`이 이미 들어 있다. 저장소
Settings → Pages → Source를 **GitHub Actions**로 한 번 바꿔 두면, `web/**`이 바뀐 채로
`main`에 푸시될 때마다 배포된다. 워크플로는 `npm ci` → `npm test`(WASM 재빌드 + 테스트
35개) → 서빙할 파일만 모아 업로드한다. 올라가는 것은 `index.html`, `styles.css`, `src/`,
`build/game_core.{js,wasm}` — 약 140KB다.

**다른 정적 호스트** — Cloudflare Pages / Netlify / Vercel도 그대로 된다. 빌드 명령은
`cd web && npm ci && npm run build`, 퍼블리시 디렉터리는 `web`(단, `node_modules`를 제외할
수 없는 호스트라면 위 워크플로처럼 필요한 파일만 따로 모아야 한다).

호스팅 쪽에서 신경 쓸 것:

- **HTTPS 필수** — ES 모듈과 모듈 워커는 `file://`로 열면 뜨지 않는다. 로컬 확인은
  `npm start`(http://localhost:4173).
- **`.wasm`은 `application/wasm`으로** — GitHub Pages·Cloudflare·Netlify는 기본으로 맞다.
- **모델은 우리가 호스팅하지 않는다** — Transformers.js가 Hugging Face Hub에서 직접 받아
  방문자 브라우저에 캐시한다. 첫 화면은 Classic Mode라 아무것도 내려받지 않고, AI Mode를
  켠 사람만 다운로드한다.
- **COOP/COEP는 걸지 않았다** — 걸면 onnxruntime이 멀티스레드로 돌지만 CDN 로딩이 까다로워진다.
  GitHub Pages는 헤더를 못 넣으므로 어차피 불가능하고, 속도가 필요하면 WebGPU를 고르는 편이 낫다.

## 구조

```
assembly/index.ts      GameCore + GameRules  → WASM. 규칙·상태·주사위·가시성·행동 칩.
build/game_core.wasm   빌드 산출물 (asc, 약 30KB)
src/engine.js          WASM의 유일한 창구. 다른 파일은 build/를 직접 import 하지 않는다.
src/scenario.js        초기 월드 + 시나리오 텍스트 (DefaultScenarioRepository)
src/intent.js          KeywordIntentParser / ChainedIntentParser / ActionResolver
src/narrator.js        TemplateNarrator / ScenarioNarrator / ResilientNarrator
src/llm.js             ContextBuilder / DMInstructions / LlmNarrator / LlmIntentParser
src/llm-worker.js      Transformers.js 워커 (추론은 메인 스레드 밖에서)
src/game.js            GameSession (GameViewModel)
src/main.js            Composition Root + DOM
```

의존 방향은 iOS와 같다: **WASM 코어는 JS를 모르고, narrator는 상태를 못 바꾸고,
LLM은 엔진에 들어오지 못한다.**

## 한 턴이 흐르는 길

```
입력 "attack the goblin"
  → KeywordIntentParser           (LLM 없이 즉시)
  → 실패하면 LlmIntentParser      (AI Mode에서만, 실패해도 게임은 계속)
  → ActionResolver                가시성 화이트리스트 안에서만 EntityID로 해석
  → WASM execute()                d20 판정 → 데미지 → 적대 NPC 반격 → 턴 +1
  → Narrator                      LLM 서사 → 실패/타임아웃이면 시나리오·템플릿 문장
```

`observe`만 턴을 소비하지 않고, **실패한 행동은 게임 시간을 쓰지 않는다**. 성공한
full-cost 행동 뒤에만 세계가 전진하고 적대 NPC가 행동한다. NPC의 행동 *선택*은 WASM의
결정론적 규칙이고, NPC의 *대사*만 LLM이 만든다.

## 실패 처리

| 실패 | 사용자에게 보이는 것 |
| --- | --- |
| 모델 로딩 실패 | Classic Mode 배너 한 줄. 게임은 그대로 진행된다. |
| LLM 타임아웃·빈 출력 | 시나리오/템플릿 문장으로 조용히 대체 (`ResilientNarrator`) |
| LLM이 수치를 지어냄 | 그 문장만 버린다. 남는 문장이 없으면 시나리오 문장으로 대체 |
| LLM이 JSON을 깨뜨림 | 건질 수 있는 만큼만 건지고, 못 건지면 "You can't do that here." |
| 없는 대상 / 모호한 대상 | DM이 되묻는다. 턴은 소비되지 않는다. |

에러 다이얼로그는 없다. AI 계층의 모든 실패는 DM의 말이거나 보이지 않는 내부 복구다.

## iOS 판과 다른 점

| | iOS | Web |
| --- | --- | --- |
| 규칙 엔진 | Swift actor (`GameEngine`) | WASM 모듈 (단일 소유자) |
| EntityID | UUID | 순증 i32 (여전히 불투명 핸들) |
| LLM | Foundation Models (4096 토큰, guardrail) | Transformers.js (모델 선택 가능) |
| 모드 전환 | 앱 재시작 필요 | 즉시 (엔진 상태가 WASM에 따로 있어서) |
| 실패 이벤트 | 빈 events 배열 | `actionRejected` 이벤트 1개 — narrator가 문장으로 만든다 |

## 아직 없는 것

- 세이브/로드. `Dice`가 시드 RNG를 들고 있어 리플레이는 가능하지만, 상태를 내보내는
  경로는 아직 만들지 않았다.
- NPC 기억(§16). `ScenarioCondition.firstMeeting`/`hostile`/`friendly`는 스키마만 있고
  `always`만 실제로 선택된다 — iOS 판과 같은 상태다.
- 교차 출처 격리(COOP/COEP) 헤더를 넣지 않아 onnxruntime은 단일 스레드 wasm으로 돈다.
  더 빠르게 하려면 WebGPU를 고르는 편이 낫다.
