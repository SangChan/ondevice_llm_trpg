import Foundation

/// 앱 UI 크롬(버튼·placeholder·에러) 전용 문자열. 게임 월드 텍스트(서사·NPC 대사)는
/// 여기 들어가지 않는다 — 프로젝트 CLAUDE.md 언어 정책: 게임 월드는 영어 고정,
/// UI 크롬만 로컬라이즈 대상.
enum AppResources {
    enum Game {
        static let title = String(localized: "game.title", defaultValue: "On-Device TRPG")
        static let inputPlaceholder = String(localized: "game.input.placeholder", defaultValue: "What do you do?")
        static let send = String(localized: "game.input.send", defaultValue: "Send")
        static let toggleActions = String(localized: "game.chipbar.toggle", defaultValue: "Show possible actions")
        static let parseFailure = String(localized: "game.error.parseFailure", defaultValue: "The DM pauses, unsure what you mean.")
    }
}
