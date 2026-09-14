import Foundation

/// `UserDefaults` 키를 한 곳에 모아 Composition Root와 SettingsView가 같은 문자열을
/// 중복해서 들고 있지 않게 한다.
enum SettingsKeys {
    /// §31 ".userChoice" — 지원 기기여도 사용자가 직접 Classic Mode를 강제할 수 있다.
    /// 반영에는 앱 재시작이 필요하다(TODO 아래 GameViewModel 참고) — 세션 중간에
    /// LanguageModelSession/GameEngine을 안전하게 다시 엮는 로직은 아직 없다.
    static let forcedClassicMode = "forcedClassicMode"
}
