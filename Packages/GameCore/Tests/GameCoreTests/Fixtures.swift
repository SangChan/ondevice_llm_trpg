import Foundation
@testable import GameCore

/// 테스트 전용 고정 월드. 결정론적 EntityID를 위해 고정 UUID 문자열을 쓴다.
enum Fixtures {
    static let forestID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    static let caveID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    static let playerID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
    static let goblinID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!)
    static let friendlyID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!)
    static let swordID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!)
    static let potionID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!)

    static func player(hp: Int = 20, armorClass: Int = 12) -> Player {
        Player(
            id: playerID,
            name: "Hero",
            location: forestID,
            stats: Stats(hp: hp, maxHP: 20, strength: 3, dexterity: 2, armorClass: armorClass)
        )
    }

    static func goblin(hp: Int = 8, disposition: Disposition = .hostile, location: EntityID = forestID) -> NPC {
        NPC(
            id: goblinID,
            name: "Goblin Scout",
            location: location,
            stats: Stats(hp: hp, maxHP: 8, strength: 2, dexterity: 1, armorClass: 10),
            disposition: disposition
        )
    }

    static func friendlyNPC(location: EntityID = forestID) -> NPC {
        NPC(
            id: friendlyID,
            name: "Old Hunter",
            location: location,
            stats: Stats(hp: 10, maxHP: 10, strength: 2, dexterity: 2, armorClass: 10),
            disposition: .friendly
        )
    }

    static func sword() -> Item {
        Item(id: swordID, name: "Rusty Sword", effect: .weapon(damageDie: 8, bonus: 1), placement: .location(forestID))
    }

    static func potion() -> Item {
        Item(id: potionID, name: "Healing Potion", effect: .consumable(healing: 5), placement: .inventory(playerID))
    }

    /// Forest ↔ Cave가 연결된 기본 맵 + 플레이어. NPC/아이템은 호출부에서 추가한다.
    static func baseState(seed: UInt64 = 1) -> GameState {
        let forest = Location(id: forestID, name: "Forgotten Forest", connections: [caveID])
        let cave = Location(id: caveID, name: "Damp Cave", connections: [forestID])

        return GameState(
            seed: seed,
            player: player(),
            locations: [forestID: forest, caveID: cave]
        )
    }
}
