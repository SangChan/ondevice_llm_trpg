// Composition Root + DOM 렌더링 (Swift `llm_trpgApp` + `GameView`에 해당).
//
// 여기 말고 어디에서도 엔진/파서/narrator를 직접 만들지 않는다. 화면은 세션이 주는
// transcript/affordances/snapshot만 그린다.

import { GameEngine } from "./engine.js";
import { buildScenario } from "./scenario.js";
import { ClassicReason, GameSession, PlayMode } from "./game.js";
import { ChainedIntentParser, KeywordIntentParser } from "./intent.js";
import { ResilientNarrator, ScenarioNarrator, TemplateNarrator } from "./narrator.js";
import { LlmClient, LlmIntentParser, LlmNarrator, MODELS } from "./llm.js";

/// 브라우저 wasm 추론은 느리다 — 여기서 기다려 주지 않으면 매 턴 폴백만 보게 된다.
const NARRATION_TIMEOUT_MS = 60_000;
const INTENT_TIMEOUT_MS = 30_000;
const LOW_HP_RATIO = 0.35;
/// 이 시간 동안 진행 이벤트가 없으면 "느린 것"이라고 알려 준다 — 멈춘 것과 구별해 준다.
const STALL_NOTICE_MS = 20_000;

const dom = {
  transcript: document.getElementById("transcript"),
  banner: document.getElementById("banner"),
  modeBadge: document.getElementById("mode-badge"),
  statusLocation: document.getElementById("status-location"),
  statusHp: document.getElementById("status-hp"),
  statusTurn: document.getElementById("status-turn"),
  hpFill: document.getElementById("hp-fill"),
  chipsToggle: document.getElementById("chips-toggle"),
  chipsList: document.getElementById("chips-list"),
  engineNote: document.getElementById("engine-note"),
  composer: document.getElementById("composer"),
  input: document.getElementById("composer-input"),
  send: document.getElementById("composer-send"),
  settings: document.getElementById("settings"),
  settingsButton: document.getElementById("settings-button"),
  settingsClose: document.getElementById("settings-close"),
  modelSelect: document.getElementById("model-select"),
  deviceSelect: document.getElementById("device-select"),
  loadModel: document.getElementById("load-model"),
  modelStatus: document.getElementById("model-status"),
  progress: document.querySelector(".progress"),
  progressFill: document.getElementById("progress-fill"),
  restart: document.getElementById("restart"),
};

const engine = new GameEngine();
const llm = new LlmClient({ onProgress: showProgress });
let session = null;
let chipsExpanded = false;
let chipsSignature = "";

/// 말풍선 노드를 id로 기억해 둔다. 스트리밍 중에 트랜스크립트를 통째로 다시 만들면
/// 모든 말풍선의 등장 애니메이션이 매 토큰 다시 재생되면서 화면이 떨린다.
const entryNodes = new Map();
const thinkingIndicator = createThinkingIndicator();

for (const model of MODELS) {
  dom.modelSelect.add(new Option(model.label, model.id));
}
dom.modelSelect.value = MODELS[1].id;

if (!navigator.gpu) {
  const webgpuOption = dom.deviceSelect.querySelector('option[value="webgpu"]');
  webgpuOption.disabled = true;
  webgpuOption.textContent = "WebGPU (not available in this browser)";
}

// MARK: - 세션

function startNewGame() {
  const scenario = buildScenario(engine);
  session = new GameSession({ engine, scenario, onChange: render });

  // 새 세션은 엔트리 id를 1부터 다시 쓴다 — 이전 판의 노드를 지우지 않으면 재사용된다.
  for (const node of entryNodes.values()) node.remove();
  entryNodes.clear();
  chipsSignature = "";

  if (llm.ready) applyAIMode();
  else session.useClassicMode(ClassicReason.deviceNotEligible);

  render();
  session.start();
}

/// LLM이 준비된 경우에만 AI Mode를 엮는다. 실패는 전부 Classic Mode로 흡수된다.
///
/// narrator는 3층이다: 작가가 쓴 문장이 있는 사건은 그대로 쓰고(ScenarioNarrator),
/// 나머지(전투·아이템)만 LLM이 쓰고, LLM이 실패하면 템플릿이 받는다. 브라우저에서
/// 돌릴 수 있는 크기의 모델에게 장소 묘사까지 맡기면 작가의 문장만 잃는다.
function applyAIMode() {
  session.useAIMode({
    parser: new ChainedIntentParser(
      new KeywordIntentParser(),
      new LlmIntentParser(llm, { timeoutMs: INTENT_TIMEOUT_MS })
    ),
    narrator: new ScenarioNarrator(
      session.scenario.script,
      new ResilientNarrator(
        new LlmNarrator(llm, { timeoutMs: NARRATION_TIMEOUT_MS }),
        new TemplateNarrator(),
        NARRATION_TIMEOUT_MS
      )
    ),
  });
}

function selectedMode() {
  return document.querySelector('input[name="mode"]:checked').value;
}

// MARK: - 렌더링

/// 첫 갱신은 즉시 그리고, 뒤따르는 갱신만 묶는다. 턴 단위 갱신은 드물어 바로 보여야 하고,
/// 토큰 스트리밍만 초당 수십 번 들어온다. (requestAnimationFrame은 배경 탭에서 멈추므로
/// 쓰지 않는다 — 탭을 옮겨 두면 서사가 그려지지 않는다.)
const MIN_RENDER_INTERVAL_MS = 50;
let lastRenderAt = 0;
let trailingRender = null;

function render() {
  const now = performance.now();
  const sinceLast = now - lastRenderAt;

  if (sinceLast >= MIN_RENDER_INTERVAL_MS) {
    lastRenderAt = now;
    renderNow();
    return;
  }
  if (trailingRender) return;

  // 마지막 갱신이 묻히지 않도록 꼬리 렌더를 한 번 예약한다.
  trailingRender = setTimeout(() => {
    trailingRender = null;
    lastRenderAt = performance.now();
    renderNow();
  }, MIN_RENDER_INTERVAL_MS - sinceLast);
}

function renderNow() {
  renderTranscript();
  renderStatus();
  renderChips();
  renderMode();

  const locked = session.isThinking || session.isOver;
  dom.input.disabled = locked;
  dom.send.disabled = locked;
  dom.input.placeholder = session.isOver ? "The adventure is over." : "What do you do?";
}

function renderTranscript() {
  const atBottom =
    dom.transcript.scrollHeight - dom.transcript.scrollTop - dom.transcript.clientHeight < 80;

  const live = new Set();
  for (const entry of session.transcript) {
    // 아직 한 글자도 오지 않은 줄은 그리지 않는다 — 빈 말풍선 대신 점 세 개를 보여준다.
    if (!entry.text) continue;
    live.add(entry.id);

    let node = entryNodes.get(entry.id);
    if (!node) {
      node = document.createElement("div");
      node.className = `entry entry-${entry.kind}`;
      entryNodes.set(entry.id, node);
      dom.transcript.append(node);
    }
    if (node.textContent !== entry.text) node.textContent = entry.text;
    node.classList.toggle("entry-streaming", Boolean(entry.streaming));
  }

  for (const [id, node] of entryNodes) {
    if (live.has(id)) continue;
    node.remove();
    entryNodes.delete(id);
  }

  const streamingNow = session.transcript.some((entry) => entry.streaming && entry.text);
  thinkingIndicator.hidden = !session.isThinking || streamingNow;
  // 이미 마지막 자식이면 건드리지 않는다 — 노드를 옮기면 점 애니메이션이 처음부터 다시 뛴다.
  if (dom.transcript.lastElementChild !== thinkingIndicator) dom.transcript.append(thinkingIndicator);

  if (atBottom) dom.transcript.scrollTop = dom.transcript.scrollHeight;
}

function createThinkingIndicator() {
  const node = document.createElement("div");
  node.className = "thinking";
  node.hidden = true;
  node.append(...[0, 1, 2].map(() => document.createElement("span")));
  return node;
}

function renderStatus() {
  const snapshot = session.snapshot;
  dom.statusLocation.textContent = snapshot.location.name;
  dom.statusHp.textContent = `${snapshot.player.hp}/${snapshot.player.maxHp}`;
  dom.statusTurn.textContent = String(snapshot.turn);

  const ratio = snapshot.player.maxHp === 0 ? 0 : snapshot.player.hp / snapshot.player.maxHp;
  dom.hpFill.style.width = `${Math.max(0, ratio) * 100}%`;
  dom.hpFill.classList.toggle("low", ratio <= LOW_HP_RATIO);
}

function renderChips() {
  dom.chipsList.hidden = !chipsExpanded;
  dom.chipsToggle.textContent = chipsExpanded ? "Hide possible actions" : "Show possible actions";
  if (!chipsExpanded) return;

  // 행동 목록이 실제로 바뀔 때만 다시 만든다. 토큰마다 버튼을 새로 찍으면 커서가
  // 올라가 있던 칩이 매번 초기화된다.
  const signature = session.affordances.map((affordance) => affordance.id).join("|");
  if (signature !== chipsSignature) {
    chipsSignature = signature;
    dom.chipsList.replaceChildren(
      ...session.affordances.map((affordance) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "chip";
        button.textContent = affordance.label;
        button.addEventListener("click", () => session.tapAffordance(affordance));
        return button;
      })
    );
  }

  const locked = session.isThinking || session.isOver;
  for (const button of dom.chipsList.children) button.disabled = locked;
}

function renderMode() {
  const isAI = session.playMode === PlayMode.ai;
  dom.modeBadge.textContent = isAI ? "AI Mode" : "Classic Mode";
  dom.modeBadge.className = `badge ${isAI ? "badge-ai" : "badge-classic"}`;
  dom.engineNote.textContent = isAI
    ? `deterministic · wasm rules + ${llm.device}`
    : "deterministic · wasm rules";

  const banner = bannerText(session.classicReason);
  dom.banner.hidden = isAI || !banner;
  dom.banner.textContent = banner ?? "";
}

/// 영구히 불가능한 일(`deviceNotEligible`)과 사용자가 직접 고른 경우(`userChoice`)는
/// 안내하지 않는다 — 고칠 수 없는 것을 띄우거나, 방금 고른 것을 다시 알리지 않는다.
function bannerText(reason) {
  switch (reason) {
    case ClassicReason.modelNotReady:
      return "The language model could not be loaded. Playing in Classic Mode for now.";
    case ClassicReason.deviceNotEligible:
    case ClassicReason.userChoice:
    default:
      return null;
  }
}

/// 모델 다운로드 상태. 파일 하나(model_q4.onnx)가 전체의 99%라, 파일별 퍼센트를 그대로
/// 보여주면 진행이 멈춘 것처럼 보인다. 바이트를 합산해 하나의 막대로 만든다.
const download = { files: new Map(), startedAt: 0, lastEventAt: 0, ticker: null };

function beginProgress() {
  download.files.clear();
  download.startedAt = Date.now();
  download.lastEventAt = Date.now();
  dom.progress.hidden = false;
  dom.progress.classList.remove("indeterminate");
  dom.progressFill.style.width = "0%";
  dom.modelStatus.classList.remove("error");
  // 다운로드가 끝난 뒤 세션을 만드는 구간에는 이벤트가 한 개도 오지 않는다.
  // 경과 시간이라도 움직여야 멈춘 것과 구별된다.
  clearInterval(download.ticker);
  download.ticker = setInterval(renderProgress, 1000);
  renderProgress();
}

function endProgress(text, { error = false } = {}) {
  clearInterval(download.ticker);
  download.ticker = null;
  dom.progress.classList.remove("indeterminate");
  dom.modelStatus.textContent = text;
  dom.modelStatus.classList.toggle("error", error);
}

function showProgress(event) {
  if (!event.file) return;

  const file = download.files.get(event.file) ?? { loaded: 0, total: 0, done: false };
  if (event.status === "progress") {
    file.loaded = event.loaded ?? file.loaded;
    file.total = event.total ?? file.total;
  } else if (event.status === "done") {
    file.done = true;
    file.loaded = file.total;
  }
  download.files.set(event.file, file);
  download.lastEventAt = Date.now();
  renderProgress();
}

function renderProgress() {
  const files = [...download.files.values()];
  const total = files.reduce((sum, file) => sum + file.total, 0);
  const loaded = files.reduce((sum, file) => sum + file.loaded, 0);
  const downloading = files.length === 0 || files.some((file) => !file.done);
  const seconds = Math.round((Date.now() - download.startedAt) / 1000);

  if (downloading && total > 0) {
    const percent = Math.min(100, (loaded / total) * 100);
    dom.progress.classList.remove("indeterminate");
    dom.progressFill.style.width = `${percent.toFixed(1)}%`;

    const stalled = Date.now() - download.lastEventAt > STALL_NOTICE_MS;
    dom.modelStatus.textContent =
      `Downloading — ${percent.toFixed(0)}% (${megabytes(loaded)} / ${megabytes(total)} MB) · ${seconds}s` +
      (stalled ? " · the Hub is slow right now, still connected" : "");
    return;
  }

  // 파일은 다 받았는데 아직 ready가 아니다 = 세션 생성 중. 퍼센트가 없으므로 막대를
  // 불확정 상태로 돌린다.
  dom.progress.classList.add("indeterminate");
  dom.modelStatus.textContent = files.length === 0
    ? `Contacting the Hub… · ${seconds}s`
    : `Preparing the model — first run only · ${seconds}s`;
}

function megabytes(bytes) {
  return (bytes / 1024 / 1024).toFixed(0);
}

// MARK: - 이벤트 배선

dom.composer.addEventListener("submit", (event) => {
  event.preventDefault();
  const text = dom.input.value;
  dom.input.value = "";
  session.submitFreeText(text);
});

dom.chipsToggle.addEventListener("click", () => {
  chipsExpanded = !chipsExpanded;
  renderChips();
});

dom.settingsButton.addEventListener("click", () => {
  document.querySelector(`input[name="mode"][value="${session.playMode}"]`).checked = true;
  dom.settings.hidden = false;
});

dom.settingsClose.addEventListener("click", () => {
  dom.settings.hidden = true;
});

dom.settings.addEventListener("click", (event) => {
  if (event.target === dom.settings) dom.settings.hidden = true;
});

for (const radio of document.querySelectorAll('input[name="mode"]')) {
  radio.addEventListener("change", async () => {
    if (selectedMode() === PlayMode.classic) {
      session.useClassicMode(ClassicReason.userChoice);
      return;
    }
    if (llm.ready) applyAIMode();
    else await loadModel();
  });
}

dom.loadModel.addEventListener("click", loadModel);

dom.restart.addEventListener("click", () => {
  dom.settings.hidden = true;
  chipsExpanded = false;
  startNewGame();
});

/// 모델 로딩 실패는 게임을 막지 않는다 — Classic Mode로 계속 플레이한다.
async function loadModel() {
  if (llm.isLoading) return;

  dom.loadModel.disabled = true;
  beginProgress();

  try {
    await llm.load({ modelId: dom.modelSelect.value, device: dom.deviceSelect.value, dtype: "q4" });
    dom.progressFill.style.width = "100%";
    endProgress(`Ready — ${dom.modelSelect.value} on ${llm.device}.`);
    document.querySelector('input[name="mode"][value="ai"]').checked = true;
    applyAIMode();
  } catch (error) {
    console.error("[llm] load failed:", error);
    endProgress(`Could not load the model: ${error.message}`, { error: true });
    dom.progress.hidden = true;
    document.querySelector('input[name="mode"][value="classic"]').checked = true;
    session.useClassicMode(ClassicReason.modelNotReady);
  } finally {
    dom.loadModel.disabled = false;
  }
}

// 부팅은 맨 마지막이다 — 위쪽에서 부르면 아래에 선언된 렌더 상태를 초기화 전에 건드린다.
startNewGame();
