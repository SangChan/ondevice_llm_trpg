import GameAI
import SwiftUI

/// 재시작이 필요하다는 걸 숨기지 않는다 — 세션 중간에 parser/narrator를 안전하게
/// 갈아끼우는 로직이 아직 없어서다(§31 ".userChoice", `SettingsKeys` 참고).
struct SettingsView: View {
    let currentMode: PlayMode
    @AppStorage(SettingsKeys.forcedClassicMode) private var forcedClassicMode = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(AppResources.Settings.currentMode, value: modeDescription)
                } footer: {
                    Text(AppResources.Settings.currentModeFooter)
                }

                Section {
                    Toggle(AppResources.Settings.forceClassicToggle, isOn: $forcedClassicMode)
                } footer: {
                    Text(AppResources.Settings.forceClassicFooter)
                }
            }
            .navigationTitle(AppResources.Settings.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppResources.Settings.done) { dismiss() }
                }
            }
        }
    }

    private var modeDescription: String {
        switch currentMode {
        case .ai:
            return AppResources.Settings.modeAI
        case .classic:
            return AppResources.Settings.modeClassic
        }
    }
}
