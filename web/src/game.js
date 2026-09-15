// 한 판의 게임 진행 (Swift `GameViewModel`에 해당).
//
// 실패 분류(파싱 실패 / 모호함 / 대상 없음 / 미지원)는 전부 여기서 흡수한다.
// UI는 transcript와 affordances만 그린다 — 에러 다이얼로그는 만들지 않는다.

import { ActionKind, NO_ENTITY } from "./engine.js";
import { ActionResolver, KeywordIntentParser, ResolveStatus } from "./intent.js";
import { narrationContext, ScenarioNarrator } from "./narrator.js";

export const PlayMode = Object.freeze({ ai: "ai", classic: "classic" });

/// Classic Mode로 들어간 이유. 어떤 경우도 게임 진입을 막지 않는다.
export const ClassicReason = Object.freeze({
  deviceNotEligible: "deviceNotEligible",
  modelNotReady: "modelNotReady",
  userChoice: "userChoice",
});

export class GameSession {
  #resolver = new ActionResolver();
  #entryId = 0;

  constructor({ engine, scenario, onChange }) {
    this.engine = engine;
    this.scenario = scenario;
    this.onChange = onChange ?? (() => {});

    this.parser = new KeywordIntentParser();
    this.narrator = new ScenarioNarrator(scenario.script);
    this.playMode = PlayMode.classic;
    this.classicReason = ClassicReason.deviceNotEligible;

    this.transcript = [];
    this.affordances = [];
    this.isThinking = false;
    this.isOver = false;
    this.questComplete = false;
  }

  /// 세션 중간에도 모드를 바꿀 수 있다 — iOS 앱은 재시작이 필요하지만, 여기서는
  /// 엔진 상태가 WASM에 따로 있어서 narrator/parser만 갈아끼우면 된다.
  useAIMode({ parser, narrator }) {
    this.parser = parser;
    this.narrator = narrator;
    this.playMode = PlayMode.ai;
    this.classicReason = null;
    this.#notify();
  }

  useClassicMode(reason) {
    this.parser = new KeywordIntentParser();
    this.narrator = new ScenarioNarrator(this.scenario.script);
    this.playMode = PlayMode.classic;
    this.classicReason = reason;
    this.#notify();
  }

  get snapshot() {
    return this.engine.snapshot();
  }

  /// 시작 장소 묘사도 "이동" 이벤트와 같은 경로를 태운다 — 합성 `moved` 이벤트를 하나
  /// 만들어 시나리오 narrator의 장소 묘사 매칭을 그대로 재사용한다.
  async start() {
    if (this.transcript.length > 0) return;
    this.#refreshAffordances();

    const snapshot = this.snapshot;
    await this.#narrate(
      [{ type: "moved", actor: snapshot.player.id, from: snapshot.player.locationId, to: snapshot.player.locationId }],
      snapshot
    );
  }

  async submitFreeText(input) {
    const trimmed = input.trim();
    if (!trimmed || this.isThinking || this.isOver) return;

    this.#append("player", trimmed);
    this.isThinking = true;
    this.#notify();

    try {
      const snapshot = this.snapshot;
      const intent = await this.parser.parse(trimmed, { visibleNames: visibleNames(snapshot) });
      await this.#resolveAndExecute(intent, snapshot);
    } catch (error) {
      console.warn("[game] intent parsing failed:", error.message);
      this.#append("narrator", "The DM pauses, unsure what you mean.");
    } finally {
      this.isThinking = false;
      this.#notify();
    }
  }

  /// 칩은 이미 EntityID까지 해석돼 있으므로 파싱도, 모호함도 구조적으로 없다.
  async tapAffordance(affordance) {
    if (this.isThinking || this.isOver) return;

    this.#append("player", affordance.sentence);
    this.isThinking = true;
    this.#notify();

    try {
      await this.#execute({
        kind: affordance.kind,
        primary: affordance.primary,
        secondary: affordance.secondary,
      });
    } finally {
      this.isThinking = false;
      this.#notify();
    }
  }

  async #resolveAndExecute(intent, snapshot) {
    const result = this.#resolver.resolve(intent, snapshot);

    switch (result.status) {
      case ResolveStatus.resolved:
        await this.#execute(result.action);
        return;
      case ResolveStatus.ambiguous:
        this.#append("narrator", `Which one — ${result.candidates.join(" or ")}?`);
        return;
      case ResolveStatus.notFound:
        this.#append("narrator", "There is nothing like that here.");
        return;
      default:
        this.#append("narrator", "You can't do that here.");
    }
  }

  async #execute(action) {
    const result = this.engine.execute({
      kind: action.kind,
      primary: action.primary ?? NO_ENTITY,
      secondary: action.secondary ?? NO_ENTITY,
      message: action.message ?? "",
    });

    const snapshot = this.snapshot;
    await this.#narrate(result.events, snapshot);
    this.#checkEnding(result.events, snapshot);
    this.#refreshAffordances();
  }

  /// AI Mode에서는 토큰이 도착하는 대로 한 줄을 채워 나간다. 실패하면
  /// `ResilientNarrator`가 돌려준 시나리오 문장으로 그 줄을 덮어쓴다.
  async #narrate(events, snapshot) {
    const entry = this.#append("narrator", "");
    entry.streaming = this.playMode === PlayMode.ai;

    // narrator가 넘겨주는 것은 조각이 아니라 "지금 보여줄 전체 문장"이다 — 조각을 이어
    // 붙이면 마지막에 다듬은 결과와 달라져서 읽던 글이 사라진다.
    const context = narrationContext(events, snapshot, {
      onToken: entry.streaming
        ? (text) => {
            entry.text = text;
            this.#notify();
          }
        : null,
    });

    const text = await this.narrator.narrate(context);
    entry.text = text;
    entry.streaming = false;
    this.#notify();
  }

  #checkEnding(events, snapshot) {
    const { questTargetId, victoryText, defeatText } = this.scenario.goal;

    if (!this.questComplete && events.some((e) => e.type === "entityDied" && e.entity === questTargetId)) {
      this.questComplete = true;
      this.#append("narrator", victoryText);
    }

    if (!snapshot.player.alive) {
      this.isOver = true;
      this.#append("narrator", defeatText);
    }
  }

  #refreshAffordances() {
    this.affordances = this.isOver ? [] : this.engine.affordances();
  }

  #append(kind, text) {
    const entry = { id: ++this.#entryId, kind, text, streaming: false };
    this.transcript.push(entry);
    this.#notify();
    return entry;
  }

  #notify() {
    this.onChange(this);
  }
}

/// 자유 입력을 해석할 때 참고할 수 있는 것 — 가시성 화이트리스트뿐이다.
export function visibleNames(snapshot) {
  return [
    ...snapshot.npcs.map((npc) => npc.name),
    ...snapshot.groundItems.map((item) => item.name),
    ...snapshot.location.connections.map((location) => location.name),
    ...snapshot.inventory.map((item) => item.name),
  ];
}

export { ActionKind };
