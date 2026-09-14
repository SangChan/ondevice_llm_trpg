import FoundationModels

/// 기기 제한(`UIRequiredDeviceCapabilities`)을 걸지 않기로 했으므로(§31), 이 네 가지가
/// 전부 실제로 발생한다. 어떤 경우도 게임 진입을 막지 않는다 — Classic Mode로 들어간다.
public enum ClassicReason: Sendable, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    /// Siri 언어가 지원 언어가 아닌 경우. `SystemLanguageModel.Availability`가 직접
    /// 알려주지 않으므로 `PlayMode.resolve(from:)`가 아니라 호출부(Composition Root)가
    /// 별도로 판단해서 붙인다.
    case unsupportedLanguage
    /// 지원 기기 사용자가 설정에서 직접 고른 경우(§31 "userChoice를 넣는 이유").
    case userChoice
}

public enum PlayMode: Sendable, Equatable {
    case ai
    case classic(reason: ClassicReason)
}

extension PlayMode {
    /// `deviceNotEligible`은 영구히 불가능한 일이므로 안내 없이 조용히 Classic으로
    /// 들어간다 — 이 매핑 자체는 순수 함수라 실기기 없이도 테스트 가능하다.
    public static func resolve(from availability: SystemLanguageModel.Availability) -> PlayMode {
        switch availability {
        case .available:
            return .ai
        case .unavailable(.deviceNotEligible):
            return .classic(reason: .deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .classic(reason: .appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
            return .classic(reason: .modelNotReady)
        @unknown default:
            // 새로 추가된 미지의 사유 — 안내를 잘못 띄우는 것보다 조용히 Classic으로
            // 보내는 편이 안전하다(§31 deviceNotEligible과 같은 태도).
            return .classic(reason: .deviceNotEligible)
        }
    }
}
