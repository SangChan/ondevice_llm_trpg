import SwiftUI

struct TranscriptRow: View {
    let entry: TranscriptEntry

    var body: some View {
        HStack {
            if entry.kind == .player { Spacer(minLength: 40) }

            Text(entry.text)
                .font(.body)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(entry.kind == .player ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                )
                .accessibilityLabel(entry.kind == .player ? Text("You said") : Text("The DM said"))

            if entry.kind == .narrator { Spacer(minLength: 40) }
        }
    }
}
