import SwiftUI

/// §37 "View는 ViewModel만 안다" — Repository/Engine/Parser/Narrator를 여기서
/// 직접 만들지 않는다. 전부 Composition Root(`llm_trpgApp`)에서 주입된다.
struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    init(viewModel: GameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.transcript) { entry in
                            TranscriptRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.transcript.count) {
                    guard let last = viewModel.transcript.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            if viewModel.isChipBarExpanded {
                ActionChipBar(affordances: viewModel.affordances) { affordance in
                    Task { await viewModel.tapAffordance(affordance) }
                }
                Divider()
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation { viewModel.isChipBarExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.up.circle")
                        .rotationEffect(.degrees(viewModel.isChipBarExpanded ? 180 : 0))
                        .imageScale(.large)
                }
                .accessibilityLabel(AppResources.Game.toggleActions)

                TextField(AppResources.Game.inputPlaceholder, text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .onSubmit(submit)

                Button(AppResources.Game.send, action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(AppResources.Game.title)
        .task { await viewModel.start() }
    }

    private func submit() {
        let text = inputText
        inputText = ""
        Task { await viewModel.submitFreeText(text) }
    }
}
