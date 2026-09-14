import Foundation
import GameCore
import GameAI

/// 초기 월드 상태와 시나리오 텍스트를 만든다. 생성은 Composition Root(`llm_trpgApp`)
/// 에서만 하고 View는 이 프로토콜을 직접 보지 않는다.
///
/// 보강판 §41 미결 사항 1번(시나리오 분량/작성 주체)은 아직 열려 있다 — 아래 콘텐츠는
/// 엔진·서사 파이프라인이 실제로 동작함을 보이기 위한 초안(맵 3, NPC 2)이며,
/// 최종 분량(맵 3~5, NPC 3~5)과 문장은 사용자 검수를 거쳐야 한다.
protocol ScenarioRepository: Sendable {
    func loadInitialState() -> GameState
    func loadScript() -> ScenarioScript
}

struct DefaultScenarioRepository: ScenarioRepository {
    // 결정론적 EntityID — 매 실행마다 같은 세계가 나와야 세이브/디버깅이 재현 가능하다.
    private let clearingID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-000000000001")!)
    private let caveID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-000000000002")!)
    private let shrineID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-000000000003")!)
    private let playerID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-0000000000A1")!)
    private let hunterID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-0000000000B1")!)
    private let goblinID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-0000000000B2")!)
    private let keeperID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-0000000000B3")!)
    private let swordID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-0000000000C1")!)
    private let potionID = EntityID(UUID(uuidString: "10000000-0000-0000-0000-0000000000C2")!)

    func loadInitialState() -> GameState {
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
        let keeper = NPC(
            id: keeperID,
            name: "Shrine Keeper",
            location: shrineID,
            stats: Stats(hp: 12, maxHP: 12, strength: 2, dexterity: 2, armorClass: 11),
            disposition: .neutral
        )
        let sword = Item(
            id: swordID,
            name: "Rusty Sword",
            effect: .weapon(damageDie: 8, bonus: 1),
            placement: .location(clearingID)
        )
        let potion = Item(
            id: potionID,
            name: "Healing Potion",
            effect: .consumable(healing: 5),
            placement: .location(caveID)
        )

        return GameState(
            seed: 20260914,
            player: player,
            locations: [clearingID: clearing, caveID: cave, shrineID: shrine],
            npcs: [hunterID: hunter, goblinID: goblin, keeperID: keeper],
            items: [swordID: sword, potionID: potion]
        )
    }

    func loadScript() -> ScenarioScript {
        ScenarioScript(
            locationDescriptions: [
                clearingID: "Sunlight filters through the trees onto a quiet forest clearing. A narrow path leads north into darkness.",
                caveID: "The air turns cold and damp. Water drips somewhere in the dark, and the path continues deeper toward a faint light.",
                shrineID: "An old stone shrine stands half-swallowed by moss, untouched for what looks like centuries."
            ],
            npcLines: [
                hunterID: [
                    ScenarioLine(condition: .always, text: "\"Careful in the cave,\" the old hunter says. \"Something's been lurking in there.\"")
                ],
                goblinID: [
                    ScenarioLine(condition: .always, text: "The goblin scout bares its teeth and raises a notched blade.")
                ],
                keeperID: [
                    ScenarioLine(condition: .always, text: "The shrine keeper studies you a long moment, then says nothing at all.")
                ]
            ],
            eventOverrides: [
                .npcDefeated(goblinID): "The goblin scout collapses and does not move again. The cave falls silent."
            ]
        )
    }
}
