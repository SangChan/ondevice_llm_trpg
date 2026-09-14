//
//  llm_trpgApp.swift
//  llm-trpg
//
//  Created by sangchan on 9/14/26.
//

import SwiftUI
import Foundation
import FoundationModels
import GameCore
import GameAI

/// Composition Root — Repository/Engine/Parser/Narrator 생성은 오직 여기서만 한다
/// (§37 "View 안 DefaultXxxRepository(...) 보유 금지"). `PlayMode`는 여기서 한 번만
/// 정해지고 세션 중간에 바뀌지 않는다(`SettingsKeys` 참고).
@main
struct llm_trpgApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                GameView(viewModel: Self.makeGameViewModel())
            }
        }
    }

    @MainActor
    private static func makeGameViewModel() -> GameViewModel {
        let repository: any ScenarioRepository = DefaultScenarioRepository()
        let initialState = repository.loadInitialState()
        let script = repository.loadScript()
        let scenarioNarrator = ScenarioNarrator(script: script)

        let engine = GameEngine(state: initialState, dice: Dice(seed: initialState.seed))
        let playMode = resolvePlayMode()

        let parser: any IntentParsing
        let narrator: any Narrating

        switch playMode {
        case .ai:
            // 칩 경로는 LLM을 호출하지 않는다(§31-1) — KeywordIntentParser가 먼저 시도하고,
            // .unknown일 때만 FoundationModels로 넘어간다. guardrail·컨텍스트 초과 등
            // primary 실패는 전부 ScenarioNarrator로 조용히 폴백한다(§33).
            parser = ChainedIntentParser(fast: KeywordIntentParser(), fallback: FoundationModelsIntentParser())
            narrator = ResilientNarrator(primary: NarrationSessionManager(), fallback: scenarioNarrator)

        case .classic:
            parser = KeywordIntentParser()
            narrator = scenarioNarrator
        }

        return GameViewModel(engine: engine, parser: parser, narrator: narrator, playMode: playMode)
    }

    /// 사용자가 설정에서 강제한 Classic Mode가 최우선이고, 그 외엔 실제 기기 가용성을 따른다.
    private static func resolvePlayMode() -> PlayMode {
        if UserDefaults.standard.bool(forKey: SettingsKeys.forcedClassicMode) {
            return .classic(reason: .userChoice)
        }
        return PlayMode.resolve(from: SystemLanguageModel.default.availability)
    }
}
