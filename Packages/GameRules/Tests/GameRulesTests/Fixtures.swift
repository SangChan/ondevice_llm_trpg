import Foundation
import GameCore
@testable import GameRules

/// GameCoreTests와 같은 3-locations 세계관. 모듈이 달라 fileprivate 픽스처를
/// 공유할 수 없으므로 여기서 독립적으로 만든다.
enum Fixtures {
    static let clearingID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    static let caveID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    static let shrineID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
    static let playerID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
    static let hunterID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!)
    static let goblinID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!)
    static let swordID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!)
    static let potionID = EntityID(UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!)

    static func state() -> GameState {
        let clearing = Location(id: clearingID, name: "Forest Clearing", connections: [caveID])
        let cave = Location(id: caveID, name: "Dark Cave", connections: [clearingID, shrineID])
        let shrine = Location(id: shrineID, name: "Old Shrine", connections: [caveID])

        let player = Player(
            id: playerID,
            name: "Hero",
            location: clearingID,
            stats: Stats(hp: 20, maxHP: 20, strength: 3, dexterity: 2, armorClass: 12)
        )
        let hunter = NPC(
            id: hunterID,
            name: "Old Hunter",
            location: clearingID,
            stats: Stats(hp: 10, maxHP: 10, strength: 2, dexterity: 2, armorClass: 10),
            disposition: .friendly
        )
        let goblin = NPC(
            id: goblinID,
            name: "Goblin Scout",
            location: caveID,
            stats: Stats(hp: 8, maxHP: 8, strength: 2, dexterity: 1, armorClass: 10),
            disposition: .hostile
        )
        let sword = Item(id: swordID, name: "Rusty Sword", effect: .weapon(damageDie: 8, bonus: 1), placement: .location(clearingID))
        let potion = Item(id: potionID, name: "Healing Potion", effect: .consumable(healing: 5), placement: .location(caveID))

        return GameState(
            seed: 1,
            player: player,
            locations: [clearingID: clearing, caveID: cave, shrineID: shrine],
            npcs: [hunterID: hunter, goblinID: goblin],
            items: [swordID: sword, potionID: potion]
        )
    }
}
