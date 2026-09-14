//
//  llm_trpgApp.swift
//  llm-trpg
//
//  Created by sangchan on 9/14/26.
//

import SwiftUI
import GameCore
import GameAI

/// Composition Root — Repository/Engine/Parser/Narrator 생성은 오직 여기서만 한다
/// (§37 "View 안 DefaultXxxRepository(...) 보유 금지"). 지금은 Classic Mode 고정
/// (KeywordIntentParser + ScenarioNarrator) — AI Mode 분기는 Phase 3(§40)에서 추가된다.
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

        let engine = GameEngine(state: initialState, dice: Dice(seed: initialState.seed))
        let parser: any IntentParsing = KeywordIntentParser()
        let narrator: any Narrating = ScenarioNarrator(script: script)

        return GameViewModel(engine: engine, parser: parser, narrator: narrator)
    }
}
