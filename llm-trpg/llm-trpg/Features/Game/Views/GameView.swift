import GameAI
import SwiftUI

/// §37 "View는 ViewModel만 안다" — Repository/Engine/Parser/Narrator를 여기서
/// 직접 만들지 않는다. 전부 Composition Root(`llm_trpgApp`)에서 주입된다.
struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var inputText = ""
    @State private var isSettingsPresented = false
    @FocusState private var inputFocused: Bool

    init(viewModel: GameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if case .classic(let reason) = viewModel.playMode, let banner = AppResources.Game.banner(for: reason) {
                Text(banner)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.transcript) { entry in
                            TranscriptRow(entry: entry)
                                .id(entry.id)
                        }
                        if viewModel.isThinking {
                            ProgressView()
                                .padding(.leading, 12)
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
                .disabled(viewModel.isThinking)
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
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isThinking)
            }
            .padding()
            .disabled(viewModel.isThinking)
        }
        .navigationTitle(AppResources.Game.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(AppResources.Game.settingsButton)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(currentMode: viewModel.playMode)
        }
        .task { await viewModel.start() }
    }

    private func submit() {
        let text = inputText
        inputText = ""
        Task { await viewModel.submitFreeText(text) }
    }
}
