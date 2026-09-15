/** Exported memory */
export declare const memory: WebAssembly.Memory;
// Exported runtime interface
export declare function __new(size: number, id: number): number;
export declare function __pin(ptr: number): number;
export declare function __unpin(ptr: number): void;
export declare function __collect(): void;
export declare const __rtti_base: number;
/** assembly/index/ACTION_MOVE */
export declare const ACTION_MOVE: {
  /** @type `i32` */
  get value(): number
};
/** assembly/index/ACTION_OBSERVE */
export declare const ACTION_OBSERVE: {
  /** @type `i32` */
  get value(): number
};
/** assembly/index/ACTION_TALK */
export declare const ACTION_TALK: {
  /** @type `i32` */
  get value(): number
};
/** assembly/index/ACTION_ATTACK */
export declare const ACTION_ATTACK: {
  /** @type `i32` */
  get value(): number
};
/** assembly/index/ACTION_TAKE */
export declare const ACTION_TAKE: {
  /** @type `i32` */
  get value(): number
};
/** assembly/index/ACTION_USE */
export declare const ACTION_USE: {
  /** @type `i32` */
  get value(): number
};
/**
 * assembly/index/reset
 * @param seed `i32`
 */
export declare function reset(seed: number): void;
/**
 * assembly/index/scriptRolls
 * @param csv `~lib/string/String`
 */
export declare function scriptRolls(csv: string): void;
/**
 * assembly/index/addLocation
 * @param name `~lib/string/String`
 * @returns `i32`
 */
export declare function addLocation(name: string): number;
/**
 * assembly/index/connect
 * @param a `i32`
 * @param b `i32`
 */
export declare function connect(a: number, b: number): void;
/**
 * assembly/index/setPlayer
 * @param name `~lib/string/String`
 * @param locationId `i32`
 * @param hp `i32`
 * @param maxHp `i32`
 * @param strength `i32`
 * @param dexterity `i32`
 * @param armorClass `i32`
 * @returns `i32`
 */
export declare function setPlayer(name: string, locationId: number, hp: number, maxHp: number, strength: number, dexterity: number, armorClass: number): number;
/**
 * assembly/index/addNpc
 * @param name `~lib/string/String`
 * @param locationId `i32`
 * @param hp `i32`
 * @param maxHp `i32`
 * @param strength `i32`
 * @param dexterity `i32`
 * @param armorClass `i32`
 * @param disposition `i32`
 * @returns `i32`
 */
export declare function addNpc(name: string, locationId: number, hp: number, maxHp: number, strength: number, dexterity: number, armorClass: number, disposition: number): number;
/**
 * assembly/index/addWeapon
 * @param name `~lib/string/String`
 * @param locationId `i32`
 * @param damageDie `i32`
 * @param bonus `i32`
 * @param hidden `bool`
 * @returns `i32`
 */
export declare function addWeapon(name: string, locationId: number, damageDie: number, bonus: number, hidden: boolean): number;
/**
 * assembly/index/addConsumable
 * @param name `~lib/string/String`
 * @param locationId `i32`
 * @param healing `i32`
 * @param hidden `bool`
 * @returns `i32`
 */
export declare function addConsumable(name: string, locationId: number, healing: number, hidden: boolean): number;
/**
 * assembly/index/execute
 * @param kind `i32`
 * @param primary `i32`
 * @param secondary `i32`
 * @param message `~lib/string/String`
 * @returns `~lib/string/String`
 */
export declare function execute(kind: number, primary: number, secondary: number, message: string): string;
/**
 * assembly/index/snapshot
 * @returns `~lib/string/String`
 */
export declare function snapshot(): string;
/**
 * assembly/index/affordances
 * @returns `~lib/string/String`
 */
export declare function affordances(): string;
/**
 * assembly/index/defaultWeapon
 * @returns `i32`
 */
export declare function defaultWeapon(): number;
