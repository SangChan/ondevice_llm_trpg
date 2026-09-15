// WASM 게임 엔진의 유일한 창구. 이 파일 바깥의 어떤 코드도 `build/game_core.js`를
// 직접 import 하지 않는다 — 규칙과 상태는 WASM 안에만 있고, JS는 명령을 보내고
// 결과를 읽을 뿐이다 (Swift `GameEngine` actor가 상태를 독점하는 것과 같은 경계).

import * as core from "../build/game_core.js";

/// `assembly/index.ts`의 ACTION_* 상수와 값이 같아야 한다.
export const ActionKind = Object.freeze({
  move: core.ACTION_MOVE,
  observe: core.ACTION_OBSERVE,
  talk: core.ACTION_TALK,
  attack: core.ACTION_ATTACK,
  take: core.ACTION_TAKE,
  use: core.ACTION_USE,
});

export const NO_ENTITY = -1;

/// 턴을 소비하지 않는 행동 (Swift `GameAction.turnCost`).
export function turnCost(kind) {
  return kind === ActionKind.observe ? "free" : "full";
}

export class GameEngine {
  /// 세계를 비우고 시드를 고정한다. 같은 시드 + 같은 입력 = 같은 게임.
  reset(seed) {
    core.reset(seed);
  }

  /// 테스트 전용 — 다음 주사위 눈을 고정한다.
  scriptRolls(values) {
    core.scriptRolls(values.join(","));
  }

  addLocation(name) {
    return core.addLocation(name);
  }

  connect(a, b) {
    core.connect(a, b);
  }

  setPlayer(name, locationId, stats) {
    return core.setPlayer(
      name,
      locationId,
      stats.hp,
      stats.maxHp,
      stats.strength,
      stats.dexterity,
      stats.armorClass
    );
  }

  addNpc(name, locationId, stats, disposition) {
    return core.addNpc(
      name,
      locationId,
      stats.hp,
      stats.maxHp,
      stats.strength,
      stats.dexterity,
      stats.armorClass,
      DISPOSITION[disposition]
    );
  }

  addWeapon(name, locationId, { damageDie, bonus = 0, hidden = false }) {
    return core.addWeapon(name, locationId, damageDie, bonus, hidden);
  }

  addConsumable(name, locationId, { healing, hidden = false }) {
    return core.addConsumable(name, locationId, healing, hidden);
  }

  /// 이미 EntityID까지 해석된 행동만 받는다. 문자열 대상은 여기 들어올 수 없다 —
  /// 그건 `ActionResolver`가 먼저 처리한다.
  execute(action) {
    const json = core.execute(
      action.kind,
      action.primary ?? NO_ENTITY,
      action.secondary ?? NO_ENTITY,
      action.message ?? ""
    );
    return JSON.parse(json);
  }

  snapshot() {
    return JSON.parse(core.snapshot());
  }

  affordances() {
    return JSON.parse(core.affordances());
  }

  defaultWeapon() {
    return core.defaultWeapon();
  }
}

const DISPOSITION = Object.freeze({ hostile: 0, neutral: 1, friendly: 2 });
