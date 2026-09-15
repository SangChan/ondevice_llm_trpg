// Narrating 구현체들 (Swift `GameAI.TemplateNarrator` / `ScenarioNarrator` / `ResilientNarrator`).
//
// narrator는 게임 상태를 바꿀 권한이 없다. 엔진이 이미 확정한 이벤트와 이름표만 받아
// 문장으로 옮긴다. 데미지 수치와 주사위 눈은 어떤 narrator도 문장에 넣지 않는다 —
// 숫자는 UI의 몫, 서사는 narrator의 몫이다.

/// narrator에게 넘기는 전부. 상태 접근 권한은 주지 않는다.
export function narrationContext(events, snapshot, { onToken = null } = {}) {
  return {
    playerId: snapshot.player.id,
    locationName: snapshot.location.name,
    events,
    names: snapshot.names,
    playerStatus: `HP ${snapshot.player.hp}/${snapshot.player.maxHp}`,
    visibleNpcNames: snapshot.npcs.map((npc) => npc.name).sort(),
    onToken,
  };
}

/// 조합 가능한 사건을 기계적으로 문장화한다. Classic Mode의 접착제이자 AI Mode의 폴백.
export class TemplateNarrator {
  async narrate(context) {
    const sentences = context.events
      .map((event) => sentenceFor(event, context))
      .filter((sentence) => sentence !== null);
    return sentences.length === 0 ? "Nothing happens." : sentences.join(" ");
  }
}

/// 시나리오에 적혀 있는 사건은 작가의 문장을, 나머지는 템플릿을 쓴다 (1층/2층 구조).
export class ScenarioNarrator {
  constructor(script, fallback = new TemplateNarrator()) {
    this.script = script;
    this.fallback = fallback;
  }

  async narrate(context) {
    const parts = [];
    const residual = [];

    for (const event of context.events) {
      const scripted = this.#scriptedLine(event);
      if (scripted) parts.push(scripted);
      else residual.push(event);
    }

    if (residual.length > 0) {
      // 작가의 문장은 이미 확정됐으니 스트리밍되는 글 앞에 계속 붙여 준다 — 화면에
      // 보이는 순서와 최종 문장이 같아야 한다.
      const prefix = parts.join(" ");
      const onToken = context.onToken
        ? (text) => context.onToken(prefix ? `${prefix} ${text}` : text)
        : null;
      parts.push(await this.fallback.narrate({ ...context, events: residual, onToken }));
    }

    return parts.length === 0 ? "Nothing happens." : parts.join(" ");
  }

  #scriptedLine(event) {
    switch (event.type) {
      case "moved":
        return this.script.locationDescriptions[event.to] ?? null;
      case "talked": {
        // `.always` 조건만 고른다 — 나머지 조건은 NPC 기억(누구를 이미 만났는지)이
        // 있어야 의미가 생긴다. 지금은 그 상태를 아무도 추적하지 않는다.
        const lines = this.script.npcLines[event.target] ?? [];
        return lines.find((line) => line.condition === "always")?.text ?? null;
      }
      case "entityDied":
        return this.script.eventOverrides[`npcDefeated:${event.entity}`] ?? null;
      default:
        return null;
    }
  }
}

/// primary(LLM)가 어떤 이유로든 실패하면 fallback(Classic Mode narrator)으로 조용히
/// 넘어간다. 게임 상태는 이미 엔진이 확정했으므로 narration 실패가 진행을 막아선 안 된다 —
/// 사용자에게 "생성 실패"를 노출하지 않는다.
export class ResilientNarrator {
  constructor(primary, fallback, timeoutMs) {
    this.primary = primary;
    this.fallback = fallback;
    this.timeoutMs = timeoutMs;
  }

  async narrate(context) {
    try {
      const text = await withTimeout(this.primary.narrate(context), this.timeoutMs);
      const trimmed = (text ?? "").trim();
      if (!trimmed) throw new Error("empty narration");
      return trimmed;
    } catch (error) {
      console.warn("[narrator] falling back to scripted narration:", error.message);
      return this.fallback.narrate({ ...context, onToken: null });
    }
  }
}

export function withTimeout(promise, milliseconds) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`timed out after ${milliseconds}ms`)), milliseconds);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function sentenceFor(event, context) {
  const name = (id) => (id === context.playerId ? "You" : context.names[id] ?? "something");
  // 주어가 플레이어면 2인칭 동사형, 아니면 3인칭 동사형.
  const verb = (id, third, second) => (id === context.playerId ? second : third);

  switch (event.type) {
    case "moved":
      return `You move to ${context.names[event.to] ?? "a new place"}.`;
    case "observed":
      return null; // 둘러본다는 것 자체에는 서사가 없다 — 장소 묘사는 다른 경로로 나온다.
    case "talked":
      return `You speak with ${name(event.target)}.`;
    case "attackHit":
      return `${name(event.attacker)} ${verb(event.attacker, "strikes", "strike")} ${name(event.target)}.`;
    case "attackMissed":
      return `${name(event.attacker)} ${verb(event.attacker, "attacks", "attack")} ${name(event.target)} and ${verb(event.attacker, "misses", "miss")}.`;
    case "entityDied":
      return `${name(event.entity)} ${verb(event.entity, "falls", "fall")}.`;
    case "itemTaken":
      return `You pick up ${context.names[event.item] ?? "the item"}.`;
    case "itemUsed":
      return `You use ${context.names[event.item] ?? "the item"}.`;
    case "actionRejected":
      return REJECTION_SENTENCES[event.reason] ?? "That doesn't seem possible.";
    case "rolled":
      return null; // 주사위 눈은 절대 서사에 넣지 않는다.
    default:
      return null;
  }
}

const REJECTION_SENTENCES = Object.freeze({
  actorNotFound: "That doesn't seem possible.",
  targetNotFound: "There is nothing like that here.",
  targetNotHere: "That isn't here.",
  targetAlreadyDead: "That target is already dead.",
  noConnection: "You cannot go that way.",
  itemNotHere: "There's nothing like that to take.",
  itemNotInInventory: "You don't have that.",
  itemNotUsable: "You can't use that.",
});
