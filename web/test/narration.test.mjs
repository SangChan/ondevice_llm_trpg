// 파서·Resolver·narrator 테스트 (Swift `GameRulesTests`/`GameAITests`에 대응).
// LLM은 여기에 들어오지 않는다 — AI 계층은 골든 파일과 실기기 하니스의 몫이다.

import assert from "node:assert/strict";
import { test } from "node:test";

import { ActionKind, GameEngine } from "../src/engine.js";
import { buildScenario } from "../src/scenario.js";
import {
  ActionResolver,
  ChainedIntentParser,
  IntentKind,
  KeywordIntentParser,
  ResolveStatus,
  playerIntent,
} from "../src/intent.js";
import {
  ResilientNarrator,
  ScenarioNarrator,
  TemplateNarrator,
  narrationContext,
} from "../src/narrator.js";
import {
  LlmClient,
  filteredEventDescriptions,
  parseIntentJSON,
  previewNarration,
  usableNarration,
} from "../src/llm.js";
import { countCompleteSentences } from "../src/sentences.js";

const engine = new GameEngine();
const parser = new KeywordIntentParser();
const resolver = new ActionResolver();

function freshWorld() {
  const scenario = buildScenario(engine);
  return { scenario, snapshot: engine.snapshot() };
}

test("the longest verb phrase wins so the object is not eaten", async () => {
  assert.deepEqual(await parser.parse("go to the dark cave"), {
    kind: IntentKind.move,
    target: "the dark cave",
    speech: "",
  });
  assert.equal((await parser.parse("look around")).kind, IntentKind.look);
  assert.equal((await parser.parse("attack the goblin")).target, "the goblin");
  assert.equal((await parser.parse("  ")).kind, IntentKind.unknown);
});

test("unparseable input stays unknown instead of guessing", async () => {
  const intent = await parser.parse("ponder the nature of dice");
  assert.equal(intent.kind, IntentKind.unknown);
  assert.equal(intent.target, "ponder the nature of dice");
});

test("the chained parser only calls the fallback for unknown input", async () => {
  let fallbackCalls = 0;
  const fallback = {
    async parse() {
      fallbackCalls += 1;
      return playerIntent(IntentKind.look);
    },
  };
  const chained = new ChainedIntentParser(parser, fallback);

  await chained.parse("go to the cave", {});
  assert.equal(fallbackCalls, 0);

  const intent = await chained.parse("ponder the nature of dice", {});
  assert.equal(fallbackCalls, 1);
  assert.equal(intent.kind, IntentKind.look);
});

test("a failing fallback still yields a playable turn", async () => {
  const chained = new ChainedIntentParser(parser, {
    async parse() {
      throw new Error("model unavailable");
    },
  });

  const intent = await chained.parse("ponder the nature of dice", {});
  assert.equal(intent.kind, IntentKind.unknown);
});

test("the resolver only matches inside the visibility whitelist", () => {
  const { scenario, snapshot } = freshWorld();

  const hunter = resolver.resolve(playerIntent(IntentKind.talk, "old hunter"), snapshot);
  assert.equal(hunter.status, ResolveStatus.resolved);
  assert.equal(hunter.action.kind, ActionKind.talk);
  assert.equal(hunter.action.primary, scenario.ids.hunter);

  // 수치를 지어낸 출력은 고쳐 쓰지 않고 실패로 돌린다 — 작가의 문장이 그 자리를 대신한다.
  const goblin = resolver.resolve(playerIntent(IntentKind.attack, "goblin scout"), snapshot);
  assert.equal(goblin.status, ResolveStatus.notFound);

  const nonsense = resolver.resolve(playerIntent(IntentKind.take, "excalibur"), snapshot);
  assert.equal(nonsense.status, ResolveStatus.notFound);
});

test("an ambiguous term asks back instead of picking one", () => {
  const { snapshot } = freshWorld();
  snapshot.npcs.push({ id: 99, name: "Old Hound", hp: 1, maxHp: 1, alive: true, disposition: "neutral" });

  const result = resolver.resolve(playerIntent(IntentKind.talk, "old"), snapshot);

  assert.equal(result.status, ResolveStatus.ambiguous);
  assert.deepEqual(result.candidates, ["Old Hound", "Old Hunter"]);
});

test("attacking picks up the carried weapon automatically", () => {
  const { scenario } = freshWorld();
  engine.execute({ kind: ActionKind.take, primary: scenario.ids.sword });

  const result = resolver.resolve(playerIntent(IntentKind.attack, "old hunter"), engine.snapshot());

  assert.equal(result.action.secondary, scenario.ids.sword);
});

test("the template narrator never prints damage or dice", async () => {
  const { scenario, snapshot } = freshWorld();
  const events = [
    { type: "rolled", kind: "attack", sides: 20, result: 17 },
    { type: "rolled", kind: "damage", sides: 8, result: 6 },
    { type: "attackHit", attacker: snapshot.player.id, target: scenario.ids.hunter, damage: 6 },
    { type: "entityDied", entity: scenario.ids.hunter },
  ];

  const text = await new TemplateNarrator().narrate(narrationContext(events, snapshot));

  assert.equal(text, "You strike Old Hunter. Old Hunter falls.");
  assert.ok(!/\d/.test(text), "numbers belong to the UI, not to the narration");
});

test("the narrator speaks in third person when the NPC acts", async () => {
  const { scenario, snapshot } = freshWorld();
  const events = [
    { type: "attackMissed", attacker: scenario.ids.hunter, target: snapshot.player.id },
    { type: "entityDied", entity: snapshot.player.id },
  ];

  const text = await new TemplateNarrator().narrate(narrationContext(events, snapshot));

  assert.equal(text, "Old Hunter attacks You and misses. You fall.");
});

test("rejections are narrated as the DM speaking, not as an error", async () => {
  const { snapshot } = freshWorld();
  const text = await new TemplateNarrator().narrate(
    narrationContext([{ type: "actionRejected", reason: "noConnection" }], snapshot)
  );

  assert.equal(text, "You cannot go that way.");
});

test("scripted events use the author's line and the rest falls to the template", async () => {
  const { scenario, snapshot } = freshWorld();
  const narrator = new ScenarioNarrator(scenario.script);

  const arrival = await narrator.narrate(
    narrationContext(
      [{ type: "moved", actor: snapshot.player.id, from: scenario.ids.clearing, to: scenario.ids.cave }],
      snapshot
    )
  );
  assert.ok(arrival.startsWith("The air turns cold and damp."));

  const mixed = await narrator.narrate(
    narrationContext(
      [
        { type: "talked", actor: snapshot.player.id, target: scenario.ids.hunter, message: "Hello." },
        { type: "itemTaken", actor: snapshot.player.id, item: scenario.ids.sword },
      ],
      snapshot
    )
  );
  assert.ok(mixed.includes("Careful in the cave"), "the scripted line should be used verbatim");
  assert.ok(mixed.endsWith("You pick up Rusty Sword."), "the rest should fall through to the template");
});

test("a failing narrator falls back silently instead of blocking the game", async () => {
  const { scenario, snapshot } = freshWorld();
  const exploding = {
    async narrate() {
      throw new Error("guardrail refusal");
    },
  };
  const narrator = new ResilientNarrator(exploding, new ScenarioNarrator(scenario.script), 50);

  const text = await narrator.narrate(
    narrationContext([{ type: "itemTaken", actor: snapshot.player.id, item: scenario.ids.sword }], snapshot)
  );

  assert.equal(text, "You pick up Rusty Sword.");
});

test("a narrator that hangs is replaced by the scripted one", async () => {
  const { scenario, snapshot } = freshWorld();
  const stalled = { narrate: () => new Promise(() => {}) };
  const narrator = new ResilientNarrator(stalled, new TemplateNarrator(), 30);

  const text = await narrator.narrate(
    narrationContext([{ type: "itemTaken", actor: snapshot.player.id, item: scenario.ids.sword }], snapshot)
  );

  assert.equal(text, "You pick up Rusty Sword.");
});

test("dice rolls never reach the LLM prompt", () => {
  const { scenario, snapshot } = freshWorld();
  const lines = filteredEventDescriptions(
    [
      { type: "rolled", kind: "attack", sides: 20, result: 3 },
      { type: "attackHit", attacker: snapshot.player.id, target: scenario.ids.hunter, damage: 6 },
    ],
    snapshot.names
  );

  assert.deepEqual(lines, ["Hero hit Old Hunter."]);
});

test("broken model JSON still produces a usable intent", () => {
  assert.deepEqual(parseIntentJSON('{"kind":"attack","target":"Goblin Scout"}'), {
    kind: IntentKind.attack,
    target: "Goblin Scout",
    speech: "",
  });
  assert.deepEqual(parseIntentJSON('Sure! ```json\n{"kind":"take","target":"Rusty Sword"}\n```'), {
    kind: IntentKind.take,
    target: "Rusty Sword",
    speech: "",
  });
  assert.equal(parseIntentJSON("I think you should probably rest").kind, IntentKind.unknown);
  assert.equal(parseIntentJSON('{"kind":"teleport","target":"moon"}').kind, IntentKind.unknown);
});

test("narration that breaks the DM rules is rejected, not patched up", () => {
  assert.equal(
    usableNarration("The goblin reels back, snarling. Its blade scrapes the wall."),
    "The goblin reels back, snarling. Its blade scrapes the wall."
  );

  // 수치를 지어낸 출력은 고쳐 쓰지 않고 실패로 돌린다 — 작가의 문장이 그 자리를 대신한다.
  assert.throws(() => usableNarration("[HP 30/20] You strike the goblin."), /too short/);
  assert.throws(() => usableNarration("   "), /too short/);
  assert.throws(() => usableNarration("Current Location: Dark Cave. Recent events follow."), /echoed/);
});

test("a rambling model is cut to whole sentences, never mid-sentence", () => {
  const text = usableNarration(
    "You lunge forward. The goblin stumbles back into the dark. It hisses something you cannot understand. And then the"
  );

  assert.equal(
    text,
    "You lunge forward. The goblin stumbles back into the dark. It hisses something you cannot understand."
  );
  assert.ok(/[.!?]$/.test(text), "narration must never end mid-sentence");
});

/// 워커 흉내 — 실제 Worker 없이 LlmClient의 요청 합류만 검증한다.
class FakeWorker {
  constructor() {
    this.loads = [];
    this.listeners = new Map();
  }

  addEventListener(type, listener) {
    this.listeners.set(type, listener);
  }

  postMessage(message) {
    if (message.type !== "load") return;
    this.loads.push(message.modelId);
    setTimeout(() => this.listeners.get("message")({ data: { type: "ready", modelId: message.modelId } }), 5);
  }
}

test("two load requests for the same model share one download", async () => {
  const worker = new FakeWorker();
  const client = new LlmClient({ createWorker: () => worker });

  // 설정 라디오와 Load 버튼이 동시에 누르는 상황. 예전에는 250MB를 두 번 받으면서
  // 먼저 건 약속이 영영 풀리지 않았다.
  const first = client.load({ modelId: "test/model" });
  const second = client.load({ modelId: "test/model" });

  assert.equal(first, second);
  assert.equal(client.isLoading, true);
  await Promise.all([first, second]);

  assert.deepEqual(worker.loads, ["test/model"]);
  assert.equal(client.ready, true);
  assert.equal(client.isLoading, false);
});

test("a worker that fails to start reports a usable reason", async () => {
  const worker = new FakeWorker();
  worker.postMessage = function () {
    setTimeout(() => this.listeners.get("error")({ message: "" }), 5);
  };
  const client = new LlmClient({ createWorker: () => worker });

  await assert.rejects(client.load({ modelId: "test/model" }), /failed to start/);
  assert.equal(client.ready, false);
  assert.equal(client.isLoading, false);
});

test("streaming shows exactly what the final text will keep", () => {
  const full = "You lunge forward. The goblin stumbles back. It hisses at you. And then";

  // 생성 중: 쓰는 중인 마지막 문장까지 보여준다.
  assert.equal(previewNarration("You lunge for"), "You lunge for");
  assert.equal(previewNarration("You lunge forward. The gob"), "You lunge forward. The gob");

  // 문장 수를 채우면 그 뒤는 화면에서도, 최종본에서도 빠진다 — 읽던 글이 사라지지 않는다.
  assert.equal(previewNarration(full), "You lunge forward. The goblin stumbles back. It hisses at you.");
  assert.equal(usableNarration(full), previewNarration(full));
});

test("only the sentence that leaked numbers is dropped", () => {
  const raw = "The goblin reels back. You have 12 HP left. It raises its blade again.";

  assert.equal(usableNarration(raw), "The goblin reels back. It raises its blade again.");
  // 화면에 보이던 문장이 끝에서 사라지지 않도록 미리보기도 같은 규칙을 쓴다.
  assert.equal(previewNarration(raw), usableNarration(raw));
  assert.throws(() => usableNarration("You take 6 damage."), /too short/);
});

test("the generator stops once the sentence budget is met", () => {
  assert.equal(countCompleteSentences("One. Two! Three?"), 3);
  assert.equal(countCompleteSentences("A complete one. An unfinished"), 1);
  assert.equal(countCompleteSentences(""), 0);
});
