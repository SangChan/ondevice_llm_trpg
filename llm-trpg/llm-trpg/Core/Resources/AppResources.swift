import Foundation
import GameAI

/// 앱 UI 크롬(버튼·placeholder·에러) 전용 문자열. 게임 월드 텍스트(서사·NPC 대사)는
/// 여기 들어가지 않는다 — 프로젝트 CLAUDE.md 언어 정책: 게임 월드는 영어 고정,
/// UI 크롬만 로컬라이즈 대상. `PlayMode`/`ClassicReason`은 GameAI가 소유하지만,
/// 그걸 어떤 문장으로 보여줄지는 앱 크롬의 몫이라 여기서 매핑한다.
enum AppResources {
    enum Game {
        static let title = String(localized: "game.title", defaultValue: "On-Device TRPG")
        static let inputPlaceholder = String(localized: "game.input.placeholder", defaultValue: "What do you do?")
        static let send = String(localized: "game.input.send", defaultValue: "Send")
        static let toggleActions = String(localized: "game.chipbar.toggle", defaultValue: "Show possible actions")
        static let parseFailure = String(localized: "game.error.parseFailure", defaultValue: "The DM pauses, unsure what you mean.")
        static let settingsButton = String(localized: "game.settings.button", defaultValue: "Settings")

        /// §31 "안내는 배너나 설정 화면에 둔다". `deviceNotEligible`·`userChoice`는 `nil` —
        /// 전자는 영구히 불가능한 일을 요구하지 않기 위해 조용히, 후자는 사용자가 직접
        /// 고른 것이라 안내가 필요 없다.
        static func banner(for reason: ClassicReason) -> String? {
            switch reason {
            case .deviceNotEligible:
                return nil
            case .appleIntelligenceNotEnabled:
                return String(localized: "game.banner.notEnabled", defaultValue: "Turn on Apple Intelligence in Settings for AI-narrated play.")
            case .modelNotReady:
                return String(localized: "game.banner.modelNotReady", defaultValue: "The on-device model is still downloading. Playing in Classic Mode for now.")
            case .unsupportedLanguage:
                return String(localized: "game.banner.unsupportedLanguage", defaultValue: "Your Siri language isn't supported yet. Playing in Classic Mode.")
            case .userChoice:
                return nil
            }
        }
    }

    enum Settings {
        static let title = String(localized: "settings.title", defaultValue: "Settings")
        static let done = String(localized: "settings.done", defaultValue: "Done")
        static let currentMode = String(localized: "settings.currentMode", defaultValue: "Current Mode")
        static let currentModeFooter = String(localized: "settings.currentMode.footer", defaultValue: "Decided once when the app launches.")
        static let modeAI = String(localized: "settings.mode.ai", defaultValue: "AI Mode")
        static let modeClassic = String(localized: "settings.mode.classic", defaultValue: "Classic Mode")
        static let forceClassicToggle = String(localized: "settings.forceClassic.toggle", defaultValue: "Force Classic Mode")
        static let forceClassicFooter = String(localized: "settings.forceClassic.footer", defaultValue: "Play without on-device AI, even on a supported device. Restart the app for this to take effect.")
    }
}
