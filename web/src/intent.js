// PlayerIntent / KeywordIntentParser / ActionResolver
// (Swift `GameRules.PlayerIntent`, `GameAI.KeywordIntentParser`, `GameRules.ActionResolver`).
//
// 파서는 "무엇을 하려는가"까지만 만든다. 그 대상이 실제로 존재하는지는 Resolver가
// 가시성 화이트리스트(= WASM 스냅샷) 안에서만 판단한다. LLM이 무엇을 지어내든
// 이 화이트리스트 밖의 EntityID는 만들어지지 않는다.

import { ActionKind, NO_ENTITY } from "./engine.js";

export const IntentKind = Object.freeze({
  move: "move",
  look: "look",
  talk: "talk",
  attack: "attack",
  take: "take",
  use: "use",
  unknown: "unknown",
});

export function playerIntent(kind, target = "", speech = "") {
  return { kind, target, speech };
}

const MOVE_VERBS = ["go to", "go", "move to", "move", "walk to", "walk", "head to", "head", "enter", "travel to"];
const LOOK_VERBS = ["look around", "look", "observe", "examine surroundings", "search"];
const TALK_VERBS = ["talk to", "talk with", "talk", "speak to", "speak with", "speak", "ask", "greet"];
const ATTACK_VERBS = ["attack", "fight", "hit", "kill", "strike", "swing at"];
const TAKE_VERBS = ["take", "grab", "pick up", "get", "loot"];
const USE_VERBS = ["use", "drink", "eat", "consume"];

/// LLM 호출 없는 정형 입력 fast path. 대상 문자열을 EntityID로 바꾸지는 않는다.
export class KeywordIntentParser {
  async parse(input) {
    const trimmed = input.trim();
    if (!trimmed) return playerIntent(IntentKind.unknown);

    const lower = trimmed.toLowerCase();

    if (strip(lower, LOOK_VERBS) !== null) return playerIntent(IntentKind.look);

    const move = strip(lower, MOVE_VERBS);
    if (move !== null) return playerIntent(IntentKind.move, move);

    const talk = strip(lower, TALK_VERBS);
    if (talk !== null) return playerIntent(IntentKind.talk, talk);

    const attack = strip(lower, ATTACK_VERBS);
    if (attack !== null) return playerIntent(IntentKind.attack, attack);

    const take = strip(lower, TAKE_VERBS);
    if (take !== null) return playerIntent(IntentKind.take, take);

    const use = strip(lower, USE_VERBS);
    if (use !== null) return playerIntent(IntentKind.use, use);

    return playerIntent(IntentKind.unknown, trimmed);
  }
}

/// 정형 입력은 LLM 없이 즉시, 나머지만 LLM으로 (Swift `ChainedIntentParser`).
/// AI Mode에서만 쓰인다 — Classic Mode는 `KeywordIntentParser` 단독이다.
export class ChainedIntentParser {
  constructor(fast, fallback) {
    this.fast = fast;
    this.fallback = fallback;
  }

  async parse(input, context) {
    const intent = await this.fast.parse(input, context);
    if (intent.kind !== IntentKind.unknown) return intent;

    try {
      return await this.fallback.parse(input, context);
    } catch {
      // LLM 파싱 실패는 에러 다이얼로그가 되지 않는다 — 모르겠다고 말할 뿐이다.
      return playerIntent(IntentKind.unknown, input.trim());
    }
  }
}

/// 가장 긴 동사구부터 맞춰 본다("go to" > "go") — 짧은 동사가 먼저 걸려 목적어를
/// 잘라먹지 않도록.
function strip(text, verbs) {
  for (const verb of [...verbs].sort((a, b) => b.length - a.length)) {
    if (text === verb) return "";
    if (text.startsWith(verb + " ")) return text.slice(verb.length + 1).trim();
  }
  return null;
}

export const ResolveStatus = Object.freeze({
  resolved: "resolved",
  ambiguous: "ambiguous",
  notFound: "notFound",
  unsupported: "unsupported",
});

/// 자연어 대상 표현을 실제 EntityID로 바꾼다. 후보는 오직 스냅샷이 준 목록뿐이다.
export class ActionResolver {
  resolve(intent, snapshot) {
    switch (intent.kind) {
      case IntentKind.look:
        return { status: ResolveStatus.resolved, action: { kind: ActionKind.observe } };

      case IntentKind.move:
        return this.#match(intent.target, snapshot.location.connections, (id) => ({
          kind: ActionKind.move,
          primary: id,
        }));

      case IntentKind.talk:
        return this.#match(intent.target, snapshot.npcs, (id) => ({
          kind: ActionKind.talk,
          primary: id,
          message: intent.speech || "Hello.",
        }));

      case IntentKind.attack:
        return this.#match(intent.target, snapshot.npcs, (id) => ({
          kind: ActionKind.attack,
          primary: id,
          secondary: defaultWeaponId(snapshot),
        }));

      case IntentKind.take:
        return this.#match(intent.target, snapshot.groundItems, (id) => ({
          kind: ActionKind.take,
          primary: id,
        }));

      case IntentKind.use:
        return this.#match(intent.target, snapshot.inventory, (id) => ({
          kind: ActionKind.use,
          primary: id,
        }));

      default:
        return { status: ResolveStatus.unsupported };
    }
  }

  #match(term, catalog, build) {
    const candidates = matchEntities(term, catalog);
    if (candidates.length === 0) return { status: ResolveStatus.notFound, term };
    if (candidates.length === 1) return { status: ResolveStatus.resolved, action: build(candidates[0].id) };
    return { status: ResolveStatus.ambiguous, candidates: candidates.map((entry) => entry.name) };
  }
}

/// 정확히 일치하는 이름이 있으면 그것만, 없으면 부분 일치를 전부 후보로 남겨
/// 모호성을 드러낸다 (Swift `EntityMatcher`).
export function matchEntities(term, catalog) {
  const needle = normalize(term);
  if (!needle) return [];

  const exact = catalog.filter((entry) => normalize(entry.name) === needle);
  if (exact.length > 0) return sortByName(exact);

  const partial = catalog.filter((entry) => {
    const name = normalize(entry.name);
    return name.includes(needle) || needle.includes(name);
  });
  return sortByName(partial);
}

/// 무기를 고르는 UI가 없으므로 인벤토리의 첫 무기를 자동으로 든다.
function defaultWeaponId(snapshot) {
  const weapon = snapshot.inventory.find((item) => item.effect === "weapon");
  return weapon ? weapon.id : NO_ENTITY;
}

function normalize(text) {
  let result = text.trim().toLowerCase();
  for (const article of ["the ", "a ", "an "]) {
    if (result.startsWith(article)) result = result.slice(article.length);
  }
  return result;
}

function sortByName(entries) {
  return [...entries].sort((a, b) => a.name.localeCompare(b.name));
}
