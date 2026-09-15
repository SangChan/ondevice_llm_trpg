// 초기 월드 + 시나리오 텍스트 (Swift `DefaultScenarioRepository`의 이식).
// 월드는 WASM 엔진 안에 만들어지고, 여기서는 그 id들만 돌려받아 시나리오 텍스트에 건다.
//
// 언어 정책: 게임 월드 텍스트(장소 묘사·NPC 대사)는 영어. 주석과 UI 크롬만 한국어다.

const SEED = 20260914;

/// 작가가 미리 쓴 텍스트를 걸 수 있는 조건 (Swift `ScenarioCondition`).
/// 지금 실제로 선택되는 것은 `always`뿐이다 — `firstMeeting`/`hostile`/`friendly`는
/// "이미 만난 적 있는가" 같은 NPC 기억이 있어야 의미가 생기고, 그건 아직 없다.
export const ScenarioCondition = Object.freeze({
  always: "always",
  firstMeeting: "firstMeeting",
  hostile: "hostile",
  friendly: "friendly",
});

/// 엔진에 세계를 짓고, 그 위에 시나리오 스크립트를 얹어 돌려준다.
export function buildScenario(engine) {
  engine.reset(SEED);

  const clearing = engine.addLocation("Forest Clearing");
  const cave = engine.addLocation("Dark Cave");
  const shrine = engine.addLocation("Old Shrine");
  engine.connect(clearing, cave);
  engine.connect(cave, shrine);

  const player = engine.setPlayer("Hero", clearing, {
    hp: 20,
    maxHp: 20,
    strength: 3,
    dexterity: 2,
    armorClass: 12,
  });

  const hunter = engine.addNpc(
    "Old Hunter",
    clearing,
    { hp: 10, maxHp: 10, strength: 2, dexterity: 2, armorClass: 10 },
    "friendly"
  );
  const goblin = engine.addNpc(
    "Goblin Scout",
    cave,
    { hp: 8, maxHp: 8, strength: 2, dexterity: 1, armorClass: 10 },
    "hostile"
  );
  const keeper = engine.addNpc(
    "Shrine Keeper",
    shrine,
    { hp: 12, maxHp: 12, strength: 2, dexterity: 2, armorClass: 11 },
    "neutral"
  );

  const sword = engine.addWeapon("Rusty Sword", clearing, { damageDie: 8, bonus: 1 });
  const potion = engine.addConsumable("Healing Potion", cave, { healing: 5 });

  return {
    ids: { player, clearing, cave, shrine, hunter, goblin, keeper, sword, potion },
    /// 목표: 고블린 정찰병을 쫓아내는 것. 승패 판정은 UI가 아니라 이 스크립트가 정의한다.
    goal: {
      questTargetId: goblin,
      victoryText:
        "The clearing is safe again. Whatever the goblin scout was looking for, it will not be found today.",
      defeatText: "Your vision narrows, the forest goes quiet, and the story ends here.",
    },
    script: {
      locationDescriptions: {
        [clearing]:
          "Sunlight filters through the trees onto a quiet forest clearing. A narrow path leads north into darkness.",
        [cave]:
          "The air turns cold and damp. Water drips somewhere in the dark, and the path continues deeper toward a faint light.",
        [shrine]:
          "An old stone shrine stands half-swallowed by moss, untouched for what looks like centuries.",
      },
      npcLines: {
        [hunter]: [
          {
            condition: ScenarioCondition.always,
            text: '"Careful in the cave," the old hunter warns. "A goblin scout has been raiding this clearing all week. Drive it off, and you\'d have my thanks."',
          },
        ],
        [goblin]: [
          {
            condition: ScenarioCondition.always,
            text: "The goblin scout bares its teeth and raises a notched blade.",
          },
        ],
        [keeper]: [
          {
            condition: ScenarioCondition.always,
            text: "The shrine keeper studies you a long moment, then says nothing at all.",
          },
        ],
      },
      eventOverrides: {
        [`npcDefeated:${goblin}`]:
          "The goblin scout collapses and does not move again. The cave falls silent — whatever it was doing here, it won't trouble the clearing anymore.",
      },
    },
  };
}
