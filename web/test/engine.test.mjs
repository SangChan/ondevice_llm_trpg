// WASM 규칙 엔진 테스트. LLM 없이 게임 전체가 검증 가능해야 한다는 원칙의 실행판이다
// (Swift `GameCoreTests`에 대응).

import assert from "node:assert/strict";
import { test } from "node:test";

import { ActionKind, GameEngine, NO_ENTITY } from "../src/engine.js";
import { buildScenario } from "../src/scenario.js";

const engine = new GameEngine();

function newGame(rolls = null) {
  const scenario = buildScenario(engine);
  if (rolls) engine.scriptRolls(rolls);
  return scenario;
}

function eventTypes(result) {
  return result.events.map((event) => event.type);
}

test("moving through a connection succeeds", () => {
  const { ids } = newGame([1]); // 도착지의 고블린이 빗나가도록 고정
  const result = engine.execute({ kind: ActionKind.move, primary: ids.cave });

  assert.equal(result.outcome, "success");
  assert.equal(result.turn, 1);
  assert.equal(engine.snapshot().location.name, "Dark Cave");
  assert.deepEqual(result.events[0], {
    type: "moved",
    actor: ids.player,
    from: ids.clearing,
    to: ids.cave,
  });
});

test("moving to an unconnected location fails and does not spend the turn", () => {
  const { ids } = newGame();
  const result = engine.execute({ kind: ActionKind.move, primary: ids.shrine });

  assert.equal(result.outcome, "failure");
  assert.equal(result.failure, "noConnection");
  assert.equal(result.turn, 0);
  assert.deepEqual(eventTypes(result), ["actionRejected"]);
  assert.equal(engine.snapshot().location.name, "Forest Clearing");
});

test("observing is free and does not advance the world", () => {
  const { ids } = newGame([1]);
  engine.execute({ kind: ActionKind.move, primary: ids.cave });
  const turnAfterMove = engine.snapshot().turn;

  const result = engine.execute({ kind: ActionKind.observe });

  assert.equal(result.outcome, "success");
  assert.equal(result.turn, turnAfterMove);
  assert.deepEqual(eventTypes(result), ["observed"]);
});

test("a hostile NPC strikes back when the player spends a turn", () => {
  const { ids } = newGame([15, 4]); // 고블린: d20=15 명중, d8=4 데미지
  const result = engine.execute({ kind: ActionKind.move, primary: ids.cave });

  assert.deepEqual(eventTypes(result), ["moved", "rolled", "rolled", "attackHit"]);
  const hit = result.events.at(-1);
  assert.equal(hit.attacker, ids.goblin);
  assert.equal(hit.target, ids.player);
  assert.equal(engine.snapshot().player.hp, 16);
});

test("a killing blow reports the death and stops the counterattack", () => {
  const { ids } = newGame([1, 20, 8]); // 고블린 빗나감 → 플레이어 d20=20, d8=8
  engine.execute({ kind: ActionKind.move, primary: ids.cave });

  const result = engine.execute({ kind: ActionKind.attack, primary: ids.goblin, secondary: NO_ENTITY });

  assert.deepEqual(eventTypes(result), ["rolled", "rolled", "attackHit", "entityDied"]);
  assert.equal(result.events.at(-1).entity, ids.goblin);
  const goblin = engine.snapshot().npcs.find((npc) => npc.id === ids.goblin);
  assert.equal(goblin.alive, false);
  assert.equal(goblin.hp, 0);
});

test("attacking a dead NPC fails without spending a turn", () => {
  const { ids } = newGame([1, 20, 8]);
  engine.execute({ kind: ActionKind.move, primary: ids.cave });
  engine.execute({ kind: ActionKind.attack, primary: ids.goblin });
  const turnBefore = engine.snapshot().turn;

  const result = engine.execute({ kind: ActionKind.attack, primary: ids.goblin });

  assert.equal(result.failure, "targetAlreadyDead");
  assert.equal(engine.snapshot().turn, turnBefore);
});

test("a weapon must be in the inventory to be swung", () => {
  const { ids } = newGame([1]);
  engine.execute({ kind: ActionKind.move, primary: ids.cave });

  const result = engine.execute({ kind: ActionKind.attack, primary: ids.goblin, secondary: ids.sword });

  assert.equal(result.failure, "itemNotInInventory");
});

test("taking an item moves it from the ground into the inventory", () => {
  const { ids } = newGame();
  const result = engine.execute({ kind: ActionKind.take, primary: ids.sword });

  assert.equal(result.outcome, "success");
  const snapshot = engine.snapshot();
  assert.deepEqual(snapshot.groundItems, []);
  assert.deepEqual(
    snapshot.inventory.map((item) => item.name),
    ["Rusty Sword"]
  );
  assert.equal(engine.defaultWeapon(), ids.sword);
});

test("drinking a potion heals up to the maximum and consumes it", () => {
  const { ids } = newGame([15, 4, 1, 1]); // 이동 중 4 피해 → 이후 고블린은 계속 빗나감
  engine.execute({ kind: ActionKind.move, primary: ids.cave });
  assert.equal(engine.snapshot().player.hp, 16);

  engine.execute({ kind: ActionKind.take, primary: ids.potion });
  const result = engine.execute({ kind: ActionKind.use, primary: ids.potion });

  assert.equal(result.outcome, "success");
  const snapshot = engine.snapshot();
  assert.equal(snapshot.player.hp, 20); // 16 + 5, maxHP에서 잘린다
  assert.deepEqual(snapshot.inventory, []);
});

test("a weapon cannot be drunk", () => {
  const { ids } = newGame();
  engine.execute({ kind: ActionKind.take, primary: ids.sword });

  const result = engine.execute({ kind: ActionKind.use, primary: ids.sword });

  assert.equal(result.failure, "itemNotUsable");
});

test("affordances only offer what is actually visible here", () => {
  newGame();
  const labels = engine.affordances().map((affordance) => affordance.label);

  assert.deepEqual(labels, [
    "Look Around",
    "Go to Dark Cave",
    "Talk to Old Hunter",
    "Attack Old Hunter",
    "Take Rusty Sword",
  ]);
  // 다른 장소의 NPC/아이템은 후보에 오르지 않는다 — hallucination 방어의 원천 데이터.
  assert.ok(!labels.some((label) => label.includes("Goblin") || label.includes("Potion")));
});

test("dice rolls are never exposed without a seed of their own", () => {
  const { ids } = newGame();
  const snapshot = engine.snapshot();

  assert.equal(snapshot.player.name, "Hero");
  assert.equal(snapshot.names[ids.goblin], "Goblin Scout");
  assert.equal(snapshot.turn, 0);
});

test("the same seed replays into the same events", () => {
  const script = (ids) => [
    { kind: ActionKind.take, primary: ids.sword },
    { kind: ActionKind.move, primary: ids.cave },
    { kind: ActionKind.attack, primary: ids.goblin, secondary: ids.sword },
    { kind: ActionKind.attack, primary: ids.goblin, secondary: ids.sword },
  ];

  const run = () => {
    const { ids } = newGame();
    return script(ids).map((action) => JSON.stringify(engine.execute(action)));
  };

  const first = run();
  const second = run();

  assert.deepEqual(first, second);
  assert.ok(first.some((entry) => entry.includes("attackHit")), "the scripted run should land a hit");
});
