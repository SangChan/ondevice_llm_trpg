// GameCore + GameRules의 WASM 포팅 (Swift `Packages/GameCore`, `Packages/GameRules`).
//
// 이 모듈이 게임 상태를 독점적으로 소유한다 — JS는 HP도 인벤토리도 직접 못 바꾼다.
// JS가 할 수 있는 일은 (1) 세계를 구성하고, (2) 이미 EntityID까지 해석된 행동을
// `execute`로 넘기고, (3) 결과 이벤트를 읽는 것뿐이다. LLM은 이 경계 바깥에 있다.
//
// Swift 원본과 다른 점:
// - `EntityID`가 UUID가 아니라 순증 i32다. LLM에게 노출되지 않는 불투명 핸들이라는
//   성질은 같고, 정렬 순서가 결정론적이라는 점도 같다.
// - 실패한 행동에 `actionRejected` 이벤트를 하나 실어 보낸다. Swift 엔진은 빈 이벤트
//   배열을 돌려주는데, 그러면 narrator가 "Nothing happens."만 말하게 된다.

// MARK: - 상수 (JS 쪽 src/engine.js와 값이 같아야 한다)

export const ACTION_MOVE: i32 = 0;
export const ACTION_OBSERVE: i32 = 1;
export const ACTION_TALK: i32 = 2;
export const ACTION_ATTACK: i32 = 3;
export const ACTION_TAKE: i32 = 4;
export const ACTION_USE: i32 = 5;

const EFFECT_NONE: i32 = 0;
const EFFECT_WEAPON: i32 = 1;
const EFFECT_CONSUMABLE: i32 = 2;

const PLACEMENT_LOCATION: i32 = 0;
const PLACEMENT_INVENTORY: i32 = 1;
const PLACEMENT_CONSUMED: i32 = 2;

const DISPOSITION_HOSTILE: i32 = 0;
const DISPOSITION_NEUTRAL: i32 = 1;
const DISPOSITION_FRIENDLY: i32 = 2;

/// 무기를 들지 않았을 때의 기본 데미지 주사위 (원본 설계 §11).
const UNARMED_DAMAGE_DIE: i32 = 8;
const ATTACK_DIE: i32 = 20;
const NO_ENTITY: i32 = -1;

// MARK: - 모델

class Stats {
  hp: i32;
  maxHp: i32;
  strength: i32;
  dexterity: i32;
  armorClass: i32;

  constructor(hp: i32, maxHp: i32, strength: i32, dexterity: i32, armorClass: i32) {
    this.hp = hp;
    this.maxHp = maxHp;
    this.strength = strength;
    this.dexterity = dexterity;
    this.armorClass = armorClass;
  }

  isAlive(): bool {
    return this.hp > 0;
  }
}

class LocationEntity {
  id: i32;
  name: string;
  connections: Array<i32>;

  constructor(id: i32, name: string) {
    this.id = id;
    this.name = name;
    this.connections = new Array<i32>();
  }
}

class NpcEntity {
  id: i32;
  name: string;
  locationId: i32;
  stats: Stats;
  disposition: i32;

  constructor(id: i32, name: string, locationId: i32, stats: Stats, disposition: i32) {
    this.id = id;
    this.name = name;
    this.locationId = locationId;
    this.stats = stats;
    this.disposition = disposition;
  }
}

/// 아이템의 현재 위치는 `placementKind`/`placementOwner` 하나뿐이다 — 바닥과 인벤토리를
/// 따로 들고 있으면 이중 소스가 된다 (수정 지침 A-2).
class ItemEntity {
  id: i32;
  name: string;
  effect: i32;
  damageDie: i32;
  bonus: i32;
  healing: i32;
  placementKind: i32;
  placementOwner: i32;
  hidden: bool;

  constructor(id: i32, name: string, effect: i32, placementKind: i32, placementOwner: i32, hidden: bool) {
    this.id = id;
    this.name = name;
    this.effect = effect;
    this.damageDie = 0;
    this.bonus = 0;
    this.healing = 0;
    this.placementKind = placementKind;
    this.placementOwner = placementOwner;
    this.hidden = hidden;
  }
}

class PlayerEntity {
  id: i32;
  name: string;
  locationId: i32;
  stats: Stats;

  constructor(id: i32, name: string, locationId: i32, stats: Stats) {
    this.id = id;
    this.name = name;
    this.locationId = locationId;
    this.stats = stats;
  }
}

/// SplitMix64 — 시드만 같으면 같은 굴림이 나온다. 세이브=리플레이의 전제 (수정 지침 C).
class Dice {
  private state: u64;
  private scripted: Array<i32>;
  private cursor: i32;

  constructor(seed: u64) {
    this.state = seed;
    this.scripted = new Array<i32>();
    this.cursor = 0;
  }

  setScripted(values: Array<i32>): void {
    this.scripted = values;
    this.cursor = 0;
  }

  private nextRaw(): u64 {
    this.state = this.state + 0x9E3779B97F4A7C15;
    let z: u64 = this.state;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
    return z ^ (z >> 31);
  }

  /// 테스트용 스크립트 굴림이 남아 있으면 그것부터 쓰고, 소진되면 시드 RNG로 넘어간다.
  roll(sides: i32): i32 {
    if (this.cursor < this.scripted.length) {
      const value = this.scripted[this.cursor];
      this.cursor += 1;
      return value;
    }
    return <i32>(this.nextRaw() % <u64>sides) + 1;
  }
}

class AttackResolution {
  attackRoll: i32;
  hit: bool;
  damageDie: i32;
  damageRoll: i32;
  damage: i32;

  constructor(attackRoll: i32, hit: bool, damageDie: i32, damageRoll: i32, damage: i32) {
    this.attackRoll = attackRoll;
    this.hit = hit;
    this.damageDie = damageDie;
    this.damageRoll = damageRoll;
    this.damage = damage;
  }
}

// MARK: - 월드 (이 모듈이 유일한 소유자)

let locations: Array<LocationEntity> = new Array<LocationEntity>();
let npcs: Array<NpcEntity> = new Array<NpcEntity>();
let items: Array<ItemEntity> = new Array<ItemEntity>();
let player: PlayerEntity = new PlayerEntity(0, "", NO_ENTITY, new Stats(0, 0, 0, 0, 0));
let dice: Dice = new Dice(0);
let turn: i32 = 0;
let nextId: i32 = 1;

// MARK: - 월드 구성 (JS의 시나리오 저장소가 호출한다)

export function reset(seed: i32): void {
  locations = new Array<LocationEntity>();
  npcs = new Array<NpcEntity>();
  items = new Array<ItemEntity>();
  player = new PlayerEntity(0, "", NO_ENTITY, new Stats(0, 0, 0, 0, 0));
  dice = new Dice(<u64>seed);
  turn = 0;
  nextId = 1;
}

/// 테스트 전용 — "3,8,20" 같은 문자열로 다음 굴림들을 고정한다.
export function scriptRolls(csv: string): void {
  const parts = csv.split(",");
  const values = new Array<i32>();
  for (let i = 0; i < parts.length; i++) {
    const trimmed = parts[i].trim();
    if (trimmed.length > 0) values.push(<i32>parseInt(trimmed));
  }
  dice.setScripted(values);
}

export function addLocation(name: string): i32 {
  const id = nextId++;
  locations.push(new LocationEntity(id, name));
  return id;
}

/// 연결은 양방향이다 — 한쪽만 이어 두면 들어갔다가 못 나오는 장소가 생긴다.
export function connect(a: i32, b: i32): void {
  const left = locationIndex(a);
  const right = locationIndex(b);
  if (left < 0 || right < 0) return;
  if (!locations[left].connections.includes(b)) locations[left].connections.push(b);
  if (!locations[right].connections.includes(a)) locations[right].connections.push(a);
}

export function setPlayer(
  name: string,
  locationId: i32,
  hp: i32,
  maxHp: i32,
  strength: i32,
  dexterity: i32,
  armorClass: i32
): i32 {
  const id = nextId++;
  player = new PlayerEntity(id, name, locationId, new Stats(hp, maxHp, strength, dexterity, armorClass));
  return id;
}

export function addNpc(
  name: string,
  locationId: i32,
  hp: i32,
  maxHp: i32,
  strength: i32,
  dexterity: i32,
  armorClass: i32,
  disposition: i32
): i32 {
  const id = nextId++;
  npcs.push(new NpcEntity(id, name, locationId, new Stats(hp, maxHp, strength, dexterity, armorClass), disposition));
  return id;
}

export function addWeapon(name: string, locationId: i32, damageDie: i32, bonus: i32, hidden: bool): i32 {
  const id = nextId++;
  const item = new ItemEntity(id, name, EFFECT_WEAPON, PLACEMENT_LOCATION, locationId, hidden);
  item.damageDie = damageDie;
  item.bonus = bonus;
  items.push(item);
  return id;
}

export function addConsumable(name: string, locationId: i32, healing: i32, hidden: bool): i32 {
  const id = nextId++;
  const item = new ItemEntity(id, name, EFFECT_CONSUMABLE, PLACEMENT_LOCATION, locationId, hidden);
  item.healing = healing;
  items.push(item);
  return id;
}

// MARK: - 실행

/// 성공 + `turnCost == .full`인 행동만 세계를 전진시킨다 (수정 지침 §35).
/// 실패는 게임 시간을 소비하지 않는다 — 실패했는데 고블린에게 맞으면 안 된다.
export function execute(kind: i32, primary: i32, secondary: i32, message: string): string {
  const events = new Array<string>();
  const failure = perform(kind, primary, secondary, message, events);

  if (failure.length > 0) {
    events.push(eventRejected(failure));
    return resultJSON(false, failure, events);
  }

  // `observe`만 free — 둘러본 것만으로 적에게 맞으면 탐색이 빈곤해진다.
  if (kind != ACTION_OBSERVE) {
    advanceWorld(events);
    turn += 1;
  }

  return resultJSON(true, "", events);
}

function perform(kind: i32, primary: i32, secondary: i32, message: string, events: Array<string>): string {
  switch (kind) {
    case ACTION_MOVE: return move(primary, events);
    case ACTION_OBSERVE: return observe(events);
    case ACTION_TALK: return talk(primary, message, events);
    case ACTION_ATTACK: return attack(primary, secondary, events);
    case ACTION_TAKE: return takeItem(primary, events);
    case ACTION_USE: return useItem(primary, secondary, events);
    default: return "actorNotFound";
  }
}

function move(destination: i32, events: Array<string>): string {
  const currentIndex = locationIndex(player.locationId);
  if (currentIndex < 0) return "actorNotFound";
  if (!locations[currentIndex].connections.includes(destination)) return "noConnection";
  if (locationIndex(destination) < 0) return "noConnection";

  const from = player.locationId;
  player.locationId = destination;
  events.push(eventMoved(player.id, from, destination));
  return "";
}

function observe(events: Array<string>): string {
  events.push(eventObserved(player.id, player.locationId));
  return "";
}

function talk(targetId: i32, message: string, events: Array<string>): string {
  const index = npcIndex(targetId);
  if (index < 0) return "targetNotFound";
  if (npcs[index].locationId != player.locationId) return "targetNotHere";
  if (!npcs[index].stats.isAlive()) return "targetAlreadyDead";

  events.push(eventTalked(player.id, targetId, message.length > 0 ? message : "Hello."));
  return "";
}

function attack(targetId: i32, weaponId: i32, events: Array<string>): string {
  const index = npcIndex(targetId);
  if (index < 0) return "targetNotFound";
  if (npcs[index].locationId != player.locationId) return "targetNotHere";
  if (!npcs[index].stats.isAlive()) return "targetAlreadyDead";

  let damageDie = UNARMED_DAMAGE_DIE;
  let bonus = 0;
  if (weaponId != NO_ENTITY) {
    const weapon = itemIndex(weaponId);
    if (weapon < 0) return "itemNotInInventory";
    if (items[weapon].placementKind != PLACEMENT_INVENTORY || items[weapon].placementOwner != player.id) {
      return "itemNotInInventory";
    }
    if (items[weapon].effect == EFFECT_WEAPON) {
      damageDie = items[weapon].damageDie;
      bonus = items[weapon].bonus;
    }
  }

  const resolution = resolveAttack(player.stats.strength, damageDie, bonus, npcs[index].stats.armorClass);
  events.push(eventRolled("attack", ATTACK_DIE, resolution.attackRoll));

  if (!resolution.hit) {
    events.push(eventAttackMissed(player.id, targetId));
    return "";
  }

  events.push(eventRolled("damage", resolution.damageDie, resolution.damageRoll));
  npcs[index].stats.hp -= resolution.damage;
  events.push(eventAttackHit(player.id, targetId, resolution.damage));
  if (!npcs[index].stats.isAlive()) events.push(eventDied(targetId));
  return "";
}

function takeItem(itemId: i32, events: Array<string>): string {
  const index = itemIndex(itemId);
  if (index < 0) return "itemNotHere";
  if (items[index].placementKind != PLACEMENT_LOCATION || items[index].placementOwner != player.locationId) {
    return "itemNotHere";
  }

  items[index].placementKind = PLACEMENT_INVENTORY;
  items[index].placementOwner = player.id;
  events.push(eventItemTaken(player.id, itemId));
  return "";
}

function useItem(itemId: i32, targetId: i32, events: Array<string>): string {
  const index = itemIndex(itemId);
  if (index < 0) return "itemNotInInventory";
  if (items[index].placementKind != PLACEMENT_INVENTORY || items[index].placementOwner != player.id) {
    return "itemNotInInventory";
  }
  if (items[index].effect != EFFECT_CONSUMABLE) return "itemNotUsable";
  if (targetId != NO_ENTITY && targetId != player.id) return "targetNotFound";

  player.stats.hp = min(player.stats.maxHp, player.stats.hp + items[index].healing);
  items[index].placementKind = PLACEMENT_CONSUMED;
  items[index].placementOwner = NO_ENTITY;
  events.push(eventItemUsed(player.id, itemId));
  return "";
}

/// 플레이어가 있는 장소의 살아있는 적대 NPC를 id 순서로 행동시킨다 (수정 지침 §35).
/// 이게 없으면 NPC가 가만히 맞다가 죽는 게임이 된다. 행동 "선택"은 여기(결정론적 규칙)의
/// 몫이고, NPC의 "대사"만 JS 쪽 LLM이 만든다.
function advanceWorld(events: Array<string>): void {
  const acting = new Array<i32>();
  for (let i = 0; i < npcs.length; i++) {
    const npc = npcs[i];
    if (npc.locationId != player.locationId) continue;
    if (!npc.stats.isAlive()) continue;
    if (npc.disposition != DISPOSITION_HOSTILE) continue;
    acting.push(npc.id);
  }
  acting.sort((a: i32, b: i32) => a - b);

  for (let i = 0; i < acting.length; i++) {
    if (!player.stats.isAlive()) return;
    const npc = npcs[npcIndex(acting[i])];

    const resolution = resolveAttack(npc.stats.strength, UNARMED_DAMAGE_DIE, 0, player.stats.armorClass);
    events.push(eventRolled("attack", ATTACK_DIE, resolution.attackRoll));

    if (!resolution.hit) {
      events.push(eventAttackMissed(npc.id, player.id));
      continue;
    }

    events.push(eventRolled("damage", resolution.damageDie, resolution.damageRoll));
    player.stats.hp -= resolution.damage;
    events.push(eventAttackHit(npc.id, player.id, resolution.damage));
    if (!player.stats.isAlive()) events.push(eventDied(player.id));
  }
}

/// 원본 설계 §11의 판정 순서: d20 + strength 대 armorClass, 명중 시 데미지 주사위.
/// 플레이어 공격과 NPC 반격이 같은 계산을 쓴다.
function resolveAttack(attackerStrength: i32, damageDie: i32, bonus: i32, targetArmorClass: i32): AttackResolution {
  const attackRoll = dice.roll(ATTACK_DIE);
  if (attackRoll + attackerStrength < targetArmorClass) {
    return new AttackResolution(attackRoll, false, damageDie, 0, 0);
  }
  const damageRoll = dice.roll(damageDie);
  return new AttackResolution(attackRoll, true, damageDie, damageRoll, max(0, damageRoll + bonus));
}

// MARK: - 조회 (JS는 여기를 통해서만 세계를 본다)

/// 플레이어가 지금 볼 수 있는 것 전부. `ActionResolver`(JS)는 이 화이트리스트 밖의
/// 대상을 절대 만들 수 없다 — "존재하지 않는 NPC hallucination"에 대한 유일한 방어다
/// (수정 지침 §13-D).
export function snapshot(): string {
  const currentIndex = locationIndex(player.locationId);
  const locationName = currentIndex >= 0 ? locations[currentIndex].name : "";

  let json = "{";
  json += '"turn":' + turn.toString();
  json += ',"player":{"id":' + player.id.toString();
  json += ',"name":"' + escapeJSON(player.name) + '"';
  json += ',"hp":' + max(0, player.stats.hp).toString();
  json += ',"maxHp":' + player.stats.maxHp.toString();
  json += ',"strength":' + player.stats.strength.toString();
  json += ',"armorClass":' + player.stats.armorClass.toString();
  json += ',"alive":' + (player.stats.isAlive() ? "true" : "false");
  json += ',"locationId":' + player.locationId.toString() + "}";

  json += ',"location":{"id":' + player.locationId.toString();
  json += ',"name":"' + escapeJSON(locationName) + '"';
  json += ',"connections":[';
  if (currentIndex >= 0) {
    const connections = sortedByName(locations[currentIndex].connections);
    for (let i = 0; i < connections.length; i++) {
      const target = locationIndex(connections[i]);
      if (target < 0) continue;
      if (i > 0) json += ",";
      json += '{"id":' + locations[target].id.toString() + ',"name":"' + escapeJSON(locations[target].name) + '"}';
    }
  }
  json += "]}";

  // 죽은 NPC도 포함한다 — "쓰러진 고블린"은 여전히 지칭 가능한 대상이다.
  json += ',"npcs":[';
  const here = npcsHere();
  for (let i = 0; i < here.length; i++) {
    const npc = npcs[here[i]];
    if (i > 0) json += ",";
    json += '{"id":' + npc.id.toString();
    json += ',"name":"' + escapeJSON(npc.name) + '"';
    json += ',"hp":' + max(0, npc.stats.hp).toString();
    json += ',"maxHp":' + npc.stats.maxHp.toString();
    json += ',"alive":' + (npc.stats.isAlive() ? "true" : "false");
    json += ',"disposition":"' + dispositionName(npc.disposition) + '"}';
  }
  json += "]";

  json += ',"groundItems":[' + itemListJSON(groundItemsHere()) + "]";
  json += ',"inventory":[' + itemListJSON(inventoryItems()) + "]";
  json += ',"names":{' + namesJSON() + "}";
  json += "}";
  return json;
}

/// 지금 할 수 있는 행동 목록 (§31-1). 원천 데이터는 위 가시성 화이트리스트와 같다 —
/// 칩을 만들기 위해 새 데이터를 저작하지 않는다.
export function affordances(): string {
  let json = "[";
  json += affordanceJSON("look", "Look Around", "You look around.", ACTION_OBSERVE, NO_ENTITY, NO_ENTITY);

  const currentIndex = locationIndex(player.locationId);
  if (currentIndex >= 0) {
    const connections = sortedByName(locations[currentIndex].connections);
    for (let i = 0; i < connections.length; i++) {
      const target = locationIndex(connections[i]);
      if (target < 0) continue;
      const name = locations[target].name;
      json += "," + affordanceJSON(
        "move:" + connections[i].toString(),
        "Go to " + name,
        "You go to " + name + ".",
        ACTION_MOVE, connections[i], NO_ENTITY
      );
    }
  }

  const here = npcsHere();
  for (let i = 0; i < here.length; i++) {
    const npc = npcs[here[i]];
    if (!npc.stats.isAlive()) continue;
    json += "," + affordanceJSON(
      "talk:" + npc.id.toString(),
      "Talk to " + npc.name,
      "You talk to " + npc.name + ".",
      ACTION_TALK, npc.id, NO_ENTITY
    );
    json += "," + affordanceJSON(
      "attack:" + npc.id.toString(),
      "Attack " + npc.name,
      "You attack " + npc.name + ".",
      ACTION_ATTACK, npc.id, defaultWeapon()
    );
  }

  const ground = groundItemsHere();
  for (let i = 0; i < ground.length; i++) {
    const item = items[ground[i]];
    json += "," + affordanceJSON(
      "take:" + item.id.toString(),
      "Take " + item.name,
      "You take the " + item.name + ".",
      ACTION_TAKE, item.id, NO_ENTITY
    );
  }

  const carried = inventoryItems();
  for (let i = 0; i < carried.length; i++) {
    const item = items[carried[i]];
    if (item.effect != EFFECT_CONSUMABLE) continue;
    json += "," + affordanceJSON(
      "use:" + item.id.toString(),
      "Use " + item.name,
      "You use the " + item.name + ".",
      ACTION_USE, item.id, NO_ENTITY
    );
  }

  json += "]";
  return json;
}

/// 무기를 고르는 UI가 없으므로 인벤토리의 첫 무기를 자동으로 든다. 없으면 맨손(d8).
export function defaultWeapon(): i32 {
  const carried = inventoryItems();
  for (let i = 0; i < carried.length; i++) {
    if (items[carried[i]].effect == EFFECT_WEAPON) return items[carried[i]].id;
  }
  return NO_ENTITY;
}

// MARK: - 내부 조회 헬퍼

function locationIndex(id: i32): i32 {
  for (let i = 0; i < locations.length; i++) {
    if (locations[i].id == id) return i;
  }
  return -1;
}

function npcIndex(id: i32): i32 {
  for (let i = 0; i < npcs.length; i++) {
    if (npcs[i].id == id) return i;
  }
  return -1;
}

function itemIndex(id: i32): i32 {
  for (let i = 0; i < items.length; i++) {
    if (items[i].id == id) return i;
  }
  return -1;
}

/// 딕셔너리 순회 대신 이름 정렬 — 정렬을 빼먹으면 스냅샷이 실행마다 달라진다.
function npcsHere(): Array<i32> {
  const found = new Array<i32>();
  for (let i = 0; i < npcs.length; i++) {
    if (npcs[i].locationId == player.locationId) found.push(i);
  }
  found.sort((a: i32, b: i32) => compareStrings(npcs[a].name, npcs[b].name));
  return found;
}

function groundItemsHere(): Array<i32> {
  const found = new Array<i32>();
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (item.hidden) continue;
    if (item.placementKind == PLACEMENT_LOCATION && item.placementOwner == player.locationId) found.push(i);
  }
  found.sort((a: i32, b: i32) => compareStrings(items[a].name, items[b].name));
  return found;
}

function inventoryItems(): Array<i32> {
  const found = new Array<i32>();
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (item.placementKind == PLACEMENT_INVENTORY && item.placementOwner == player.id) found.push(i);
  }
  found.sort((a: i32, b: i32) => compareStrings(items[a].name, items[b].name));
  return found;
}

function sortedByName(ids: Array<i32>): Array<i32> {
  const copy = new Array<i32>();
  for (let i = 0; i < ids.length; i++) copy.push(ids[i]);
  copy.sort((a: i32, b: i32) => {
    const left = locationIndex(a);
    const right = locationIndex(b);
    if (left < 0 || right < 0) return a - b;
    return compareStrings(locations[left].name, locations[right].name);
  });
  return copy;
}

function compareStrings(a: string, b: string): i32 {
  const length = a.length < b.length ? a.length : b.length;
  for (let i = 0; i < length; i++) {
    const diff = a.charCodeAt(i) - b.charCodeAt(i);
    if (diff != 0) return diff;
  }
  return a.length - b.length;
}

function dispositionName(disposition: i32): string {
  if (disposition == DISPOSITION_HOSTILE) return "hostile";
  if (disposition == DISPOSITION_FRIENDLY) return "friendly";
  return "neutral";
}

function effectName(effect: i32): string {
  if (effect == EFFECT_WEAPON) return "weapon";
  if (effect == EFFECT_CONSUMABLE) return "consumable";
  return "none";
}

// MARK: - JSON 직렬화 (WASM↔JS 경계의 유일한 표현)

function itemListJSON(indices: Array<i32>): string {
  let json = "";
  for (let i = 0; i < indices.length; i++) {
    const item = items[indices[i]];
    if (i > 0) json += ",";
    json += '{"id":' + item.id.toString();
    json += ',"name":"' + escapeJSON(item.name) + '"';
    json += ',"effect":"' + effectName(item.effect) + '"}';
  }
  return json;
}

/// 이벤트 속 id를 사람이 읽을 이름으로 바꿀 표. narrator가 쓴다.
function namesJSON(): string {
  let json = '"' + player.id.toString() + '":"' + escapeJSON(player.name) + '"';
  for (let i = 0; i < locations.length; i++) {
    json += ',"' + locations[i].id.toString() + '":"' + escapeJSON(locations[i].name) + '"';
  }
  for (let i = 0; i < npcs.length; i++) {
    json += ',"' + npcs[i].id.toString() + '":"' + escapeJSON(npcs[i].name) + '"';
  }
  for (let i = 0; i < items.length; i++) {
    json += ',"' + items[i].id.toString() + '":"' + escapeJSON(items[i].name) + '"';
  }
  return json;
}

function affordanceJSON(id: string, label: string, sentence: string, kind: i32, primary: i32, secondary: i32): string {
  let json = '{"id":"' + escapeJSON(id) + '"';
  json += ',"label":"' + escapeJSON(label) + '"';
  json += ',"sentence":"' + escapeJSON(sentence) + '"';
  json += ',"kind":' + kind.toString();
  json += ',"primary":' + primary.toString();
  json += ',"secondary":' + secondary.toString() + "}";
  return json;
}

function resultJSON(success: bool, failure: string, events: Array<string>): string {
  let json = '{"outcome":"' + (success ? "success" : "failure") + '"';
  json += ',"failure":' + (failure.length > 0 ? '"' + escapeJSON(failure) + '"' : "null");
  json += ',"turn":' + turn.toString();
  json += ',"events":[';
  for (let i = 0; i < events.length; i++) {
    if (i > 0) json += ",";
    json += events[i];
  }
  json += "]}";
  return json;
}

function eventMoved(actor: i32, from: i32, to: i32): string {
  return '{"type":"moved","actor":' + actor.toString() + ',"from":' + from.toString() + ',"to":' + to.toString() + "}";
}

function eventObserved(actor: i32, location: i32): string {
  return '{"type":"observed","actor":' + actor.toString() + ',"location":' + location.toString() + "}";
}

function eventTalked(actor: i32, target: i32, message: string): string {
  return '{"type":"talked","actor":' + actor.toString() + ',"target":' + target.toString() +
    ',"message":"' + escapeJSON(message) + '"}';
}

function eventAttackHit(attacker: i32, target: i32, damage: i32): string {
  return '{"type":"attackHit","attacker":' + attacker.toString() + ',"target":' + target.toString() +
    ',"damage":' + damage.toString() + "}";
}

function eventAttackMissed(attacker: i32, target: i32): string {
  return '{"type":"attackMissed","attacker":' + attacker.toString() + ',"target":' + target.toString() + "}";
}

function eventDied(entity: i32): string {
  return '{"type":"entityDied","entity":' + entity.toString() + "}";
}

function eventItemTaken(actor: i32, item: i32): string {
  return '{"type":"itemTaken","actor":' + actor.toString() + ',"item":' + item.toString() + "}";
}

function eventItemUsed(actor: i32, item: i32): string {
  return '{"type":"itemUsed","actor":' + actor.toString() + ',"item":' + item.toString() + "}";
}

function eventRejected(reason: string): string {
  return '{"type":"actionRejected","reason":"' + escapeJSON(reason) + '"}';
}

/// 주사위 눈은 감사 로그일 뿐이다. narrator/LLM에게 넘기는 쪽에서 반드시 걸러낸다
/// (수정 지침 C).
function eventRolled(kind: string, sides: i32, result: i32): string {
  return '{"type":"rolled","kind":"' + kind + '","sides":' + sides.toString() + ',"result":' + result.toString() + "}";
}

function escapeJSON(text: string): string {
  let out = "";
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if (code == 0x22) out += '\\"';
    else if (code == 0x5c) out += "\\\\";
    else if (code == 0x0a) out += "\\n";
    else if (code == 0x0d) out += "\\r";
    else if (code == 0x09) out += "\\t";
    else if (code < 0x20) out += "\\u00" + hexByte(code);
    else out += String.fromCharCode(code);
  }
  return out;
}

function hexByte(code: i32): string {
  const digits = "0123456789abcdef";
  return digits.charAt((code >> 4) & 0xf) + digits.charAt(code & 0xf);
}
