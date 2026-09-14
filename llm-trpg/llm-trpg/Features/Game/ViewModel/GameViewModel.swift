import Foundation
import Observation
import GameCore
import GameRules
import GameAI

/// §37 "SwiftUI View에는 분기·상태·비동기 로직을 두지 않는다"를 지킨다.
/// §34의 실패 분류(파싱 실패/모호함/notFound/unsupported)는 전부 여기서 분기한다 —
/// View는 `transcript`/`affordances`만 그린다.
@MainActor
@Observable
final class GameViewModel {
    private let engine: GameEngine
    private let parser: any IntentParsing
    private let narrator: any Narrating
    private let resolver = ActionResolver()

    private(set) var transcript: [TranscriptEntry] = []
    private(set) var affordances: [ActionAffordance] = []
    var isChipBarExpanded = false

    init(engine: GameEngine, parser: any IntentParsing, narrator: any Narrating) {
        self.engine = engine
        self.parser = parser
        self.narrator = narrator
    }

    /// 화면이 뜨면 한 번 호출한다 — 시작 장소를 묘사하고 초기 행동 칩을 채운다.
    func start() async {
        guard transcript.isEmpty else { return }
        await refreshAffordances()
        await narrateArrival()
    }

    /// 자유 텍스트 입력. 실패는 전부 여기서 흡수한다 — 게임을 멈추는 에러 다이얼로그는
    /// 만들지 않는다(수정 지침 §34).
    func submitFreeText(_ input: String) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        transcript.append(TranscriptEntry(text: trimmed, kind: .player))

        let state = await engine.currentState
        let context = IntentContext(visibleEntities: state.visibleEntities(for: state.player.id))

        do {
            let intent = try await parser.parse(input: trimmed, context: context)
            await resolveAndExecute(intent)
        } catch {
            transcript.append(TranscriptEntry(text: AppResources.Game.parseFailure, kind: .narrator))
        }
    }

    /// 칩 탭. 이미 EntityID까지 해석돼 있으므로 파싱도, 모호함도 구조적으로 없다(§31-1).
    func tapAffordance(_ affordance: ActionAffordance) async {
        let state = await engine.currentState
        transcript.append(TranscriptEntry(text: state.playerSentence(for: affordance.action), kind: .player))
        await execute(affordance.action)
    }

    private func resolveAndExecute(_ intent: PlayerIntent) async {
        let state = await engine.currentState

        switch resolver.resolve(intent, actor: state.player.id, in: state) {
        case .resolved(let action):
            await execute(action)

        case .ambiguous(let candidates):
            isChipBarExpanded = true
            let names = candidates.compactMap { state.visibleEntities(for: state.player.id)[$0] }.sorted()
            transcript.append(TranscriptEntry(text: "Which one — \(names.joined(separator: " or "))?", kind: .narrator))

        case .notFound:
            transcript.append(TranscriptEntry(text: "There is nothing like that here.", kind: .narrator))

        case .unsupported:
            isChipBarExpanded = true
            transcript.append(TranscriptEntry(text: "You can't do that here.", kind: .narrator))
        }
    }

    private func execute(_ action: GameAction) async {
        let result = await engine.execute(action)
        let state = await engine.currentState

        let context = NarrationContext(
            playerID: state.player.id,
            locationName: state.locations[state.player.location]?.name ?? "",
            recentEvents: result.events,
            entityNames: Self.entityNames(in: state)
        )

        if let text = try? await narrator.narrate(context) {
            transcript.append(TranscriptEntry(text: text, kind: .narrator))
        }

        await refreshAffordances()
    }

    /// 시작 장소 묘사도 "이동" 이벤트와 같은 경로를 태운다 — 합성 `.moved` 이벤트를 하나
    /// 만들어 ScenarioNarrator의 장소 묘사 매칭을 그대로 재사용한다.
    private func narrateArrival() async {
        let state = await engine.currentState
        let arrival = GameEvent.moved(actor: state.player.id, from: state.player.location, to: state.player.location)
        let context = NarrationContext(
            playerID: state.player.id,
            locationName: state.locations[state.player.location]?.name ?? "",
            recentEvents: [arrival],
            entityNames: Self.entityNames(in: state)
        )
        if let text = try? await narrator.narrate(context) {
            transcript.append(TranscriptEntry(text: text, kind: .narrator))
        }
    }

    private func refreshAffordances() async {
        let state = await engine.currentState
        affordances = state.affordances(for: state.player.id)
    }

    private static func entityNames(in state: GameState) -> [EntityID: String] {
        var names: [EntityID: String] = [state.player.id: state.player.name]
        for npc in state.npcs.values { names[npc.id] = npc.name }
        for item in state.items.values { names[item.id] = item.name }
        for location in state.locations.values { names[location.id] = location.name }
        return names
    }
}
