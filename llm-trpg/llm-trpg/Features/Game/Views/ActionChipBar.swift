import GameRules
import SwiftUI

/// 접힌 행동 칩 바 (§31-1). 개수 배지를 두지 않는다 — 숨겨진 아이템·통로가
/// 배지 숫자만으로도 스포일러가 될 수 있다.
struct ActionChipBar: View {
    let affordances: [ActionAffordance]
    let onTap: (ActionAffordance) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(affordances) { affordance in
                    Button(affordance.label) {
                        onTap(affordance)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}
