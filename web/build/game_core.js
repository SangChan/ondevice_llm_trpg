async function instantiate(module, imports = {}) {
  const adaptedImports = {
    env: Object.setPrototypeOf({
      abort(message, fileName, lineNumber, columnNumber) {
        // ~lib/builtins/abort(~lib/string/String | null?, ~lib/string/String | null?, u32?, u32?) => void
        message = __liftString(message >>> 0);
        fileName = __liftString(fileName >>> 0);
        lineNumber = lineNumber >>> 0;
        columnNumber = columnNumber >>> 0;
        (() => {
          // @external.js
          throw Error(`${message} in ${fileName}:${lineNumber}:${columnNumber}`);
        })();
      },
    }, Object.assign(Object.create(globalThis), imports.env || {})),
  };
  const { exports } = await WebAssembly.instantiate(module, adaptedImports);
  const memory = exports.memory || imports.env.memory;
  const adaptedExports = Object.setPrototypeOf({
    scriptRolls(csv) {
      // assembly/index/scriptRolls(~lib/string/String) => void
      csv = __lowerString(csv) || __notnull();
      exports.scriptRolls(csv);
    },
    addLocation(name) {
      // assembly/index/addLocation(~lib/string/String) => i32
      name = __lowerString(name) || __notnull();
      return exports.addLocation(name);
    },
    setPlayer(name, locationId, hp, maxHp, strength, dexterity, armorClass) {
      // assembly/index/setPlayer(~lib/string/String, i32, i32, i32, i32, i32, i32) => i32
      name = __lowerString(name) || __notnull();
      return exports.setPlayer(name, locationId, hp, maxHp, strength, dexterity, armorClass);
    },
    addNpc(name, locationId, hp, maxHp, strength, dexterity, armorClass, disposition) {
      // assembly/index/addNpc(~lib/string/String, i32, i32, i32, i32, i32, i32, i32) => i32
      name = __lowerString(name) || __notnull();
      return exports.addNpc(name, locationId, hp, maxHp, strength, dexterity, armorClass, disposition);
    },
    addWeapon(name, locationId, damageDie, bonus, hidden) {
      // assembly/index/addWeapon(~lib/string/String, i32, i32, i32, bool) => i32
      name = __lowerString(name) || __notnull();
      hidden = hidden ? 1 : 0;
      return exports.addWeapon(name, locationId, damageDie, bonus, hidden);
    },
    addConsumable(name, locationId, healing, hidden) {
      // assembly/index/addConsumable(~lib/string/String, i32, i32, bool) => i32
      name = __lowerString(name) || __notnull();
      hidden = hidden ? 1 : 0;
      return exports.addConsumable(name, locationId, healing, hidden);
    },
    execute(kind, primary, secondary, message) {
      // assembly/index/execute(i32, i32, i32, ~lib/string/String) => ~lib/string/String
      message = __lowerString(message) || __notnull();
      return __liftString(exports.execute(kind, primary, secondary, message) >>> 0);
    },
    snapshot() {
      // assembly/index/snapshot() => ~lib/string/String
      return __liftString(exports.snapshot() >>> 0);
    },
    affordances() {
      // assembly/index/affordances() => ~lib/string/String
      return __liftString(exports.affordances() >>> 0);
    },
  }, exports);
  function __liftString(pointer) {
    if (!pointer) return null;
    const
      end = pointer + new Uint32Array(memory.buffer)[pointer - 4 >>> 2] >>> 1,
      memoryU16 = new Uint16Array(memory.buffer);
    let
      start = pointer >>> 1,
      string = "";
    while (end - start > 1024) string += String.fromCharCode(...memoryU16.subarray(start, start += 1024));
    return string + String.fromCharCode(...memoryU16.subarray(start, end));
  }
  function __lowerString(value) {
    if (value == null) return 0;
    const
      length = value.length,
      pointer = exports.__new(length << 1, 2) >>> 0,
      memoryU16 = new Uint16Array(memory.buffer);
    for (let i = 0; i < length; ++i) memoryU16[(pointer >>> 1) + i] = value.charCodeAt(i);
    return pointer;
  }
  function __notnull() {
    throw TypeError("value must not be null");
  }
  return adaptedExports;
}
export const {
  memory,
  __new,
  __pin,
  __unpin,
  __collect,
  __rtti_base,
  ACTION_MOVE,
  ACTION_OBSERVE,
  ACTION_TALK,
  ACTION_ATTACK,
  ACTION_TAKE,
  ACTION_USE,
  reset,
  scriptRolls,
  addLocation,
  connect,
  setPlayer,
  addNpc,
  addWeapon,
  addConsumable,
  execute,
  snapshot,
  affordances,
  defaultWeapon,
} = await (async url => instantiate(
  await (async () => {
    const isNodeOrBun = typeof process != "undefined" && process.versions != null && (process.versions.node != null || process.versions.bun != null);
    if (isNodeOrBun) { return globalThis.WebAssembly.compile(await (await import("node:fs/promises")).readFile(url)); }
    else { return await globalThis.WebAssembly.compileStreaming(globalThis.fetch(url)); }
  })(), {
  }
))(new URL("game_core.wasm", import.meta.url));
