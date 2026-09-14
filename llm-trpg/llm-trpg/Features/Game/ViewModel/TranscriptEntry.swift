import Foundation

/// 채팅 화면 한 줄. `kind`가 좌우 정렬과 말풍선 색을 결정한다(View 쪽 관심사).
struct TranscriptEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case player
        case narrator
    }

    let id = UUID()
    let text: String
    let kind: Kind
}
