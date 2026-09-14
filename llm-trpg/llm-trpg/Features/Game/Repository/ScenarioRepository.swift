import Foundation
import GameCore
import GameAI

/// 초기 월드 상태와 시나리오 텍스트를 만든다. 생성은 Composition Root(`llm_trpgApp`)
/// 에서만 하고 View는 이 프로토콜을 직접 보지 않는다.
///
/// 보강판 §41 미결 사항 1번(시나리오 분량/작성 주체)은 아직 열려 있다 — 아래는 Claude가
/// 쓴 초안이다(맵 3, NPC 3). 목표(고블린 처치)와 결말 비트는 있지만, 현재 엔진이 실제로
/// 처리할 수 있는 것만 썼다 — 지원되지 않는 걸 되는 것처럼 써 두지 않았다. 아래 TODO를
/// 검수·교체해 달라.
///
/// TODO(scenario): 고블린을 처치한 뒤 Old Hunter에게 "보고"하면 대사가 바뀌는 게
///   자연스러운데, 지금은 `ScenarioNarrator`가 `.always` 조건만 고르기 때문에(TODO 아래
///   `npcLines` 참고) 몇 번을 다시 말 걸어도 첫 대사가 반복된다.
/// TODO(scenario): Shrine Keeper는 아직 순수 장식이다 — 처치 보상, 두 번째 퀘스트,
///   아니면 그냥 분위기용 NPC로 남길지 결정이 필요하다.
/// TODO(scenario): 포션 외에 "왜 이 여정을 하는가"에 대한 더 큰 동기(가족, 마을,
///   현상금 등)가 없다 — 분량을 맵 4~5개로 늘릴 때 같이 고민할 지점.
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
            // TODO(engineering): `ScenarioNarrator.scriptedLine(for:)`가 `.always` 조건만
            // 고른다 (GameAI/ScenarioNarrator.swift 참고). `.firstMeeting`/`.hostile`/
            // `.friendly`로 대사를 갈아끼우려면 "이미 만난 적 있는가/처치했는가" 같은 상태를
            // 어딘가(GameState? NarrationContext?)에 태워야 한다 — §16 NPC Memory(5단계) 없이
            // 임시방편으로 만들 수도 있지만, 지금은 스코프 밖이라 아래는 전부 `.always`만 썼다.
            npcLines: [
                hunterID: [
                    ScenarioLine(
                        condition: .always,
                        text: "\"Careful in the cave,\" the old hunter warns. \"A goblin scout has been raiding this clearing all week. Drive it off, and you'd have my thanks.\""
                    )
                ],
                goblinID: [
                    ScenarioLine(condition: .always, text: "The goblin scout bares its teeth and raises a notched blade.")
                ],
                keeperID: [
                    // TODO(scenario): 위 파일 헤더 TODO 참고 — 지금은 순수 분위기용 대사.
                    ScenarioLine(condition: .always, text: "The shrine keeper studies you a long moment, then says nothing at all.")
                ]
            ],
            eventOverrides: [
                // 고블린 처치 = 사실상의 "엔딩" 비트. 단, 이걸 깼다고 게임이 끝나거나
                // Old Hunter의 대사가 바뀌지는 않는다 — 위 TODO(scenario) 참고.
                .npcDefeated(goblinID): "The goblin scout collapses and does not move again. The cave falls silent — whatever it was doing here, it won't trouble the clearing anymore."
            ]
        )
    }
}
