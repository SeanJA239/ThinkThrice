import CalmCore
import SwiftUI

/// The melt editor: the text reappears one piece at a time and only the pieces
/// already revealed can be edited. Submitting rescores the whole text.
struct MeltEditor: View {
    @Environment(AppModel.self) private var app
    let store: ChatStore
    let id: String
    /// The pieces of the text being rewritten, fixed when the editor opens.
    @State private var pieces: [String] = []
    @State private var edited = ""
    @State private var submitted = false

    private var revealed: Int {
        if case .rewriting(let revealed)? = store.records[id]?.state { return revealed }
        return pieces.count
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("原文冻住了，正在一句句化开；你只能改已经化开的部分。", "The original is frozen and thaws one sentence at a time; you can only edit what has thawed."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $edited)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                // Sentences not yet revealed stay frozen, one block each; each melts
                // away as it thaws into the editor above.
                let frozen = Array(pieces.enumerated()).dropFirst(revealed)
                if !frozen.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(frozen, id: \.offset) { _, piece in
                            HStack(spacing: 8) {
                                Image(systemName: "snowflake")
                                    .foregroundStyle(.cyan)
                                Text(piece)
                                    .foregroundStyle(.secondary)
                                    .blur(radius: 5)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.clear.tint(.cyan.opacity(0.18)), in: .rect(cornerRadius: 14))
                            .transition(.asymmetric(
                                insertion: .identity,
                                removal: AnyTransition(.blurReplace).combined(with: .scale(scale: 1.08)).combined(with: .move(edge: .top))
                            ))
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tr("还有 \(pieces.count - revealed) 句冻着，会一句句化开", "\(pieces.count - revealed) sentences still frozen, thawing one by one"))
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle(tr("改写", "Rewrite"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("取消", "Cancel")) {
                        store.send(id, .cancelRewrite)
                        store.route = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("重新判断", "Judge again")) { submit() }
                        .disabled(edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitted)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(tr("放下", "Let go")) {
                        store.send(id, .letGo)
                        store.route = nil
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .task { await reveal() }
    }

    private func reveal() async {
        guard pieces.isEmpty, let text = store.records[id]?.text else { return }
        pieces = Sentences.split(text)
        edited = pieces.prefix(revealed).joined()
        while revealed < pieces.count, !submitted {
            try? await Task.sleep(for: .seconds(app.policy.meltRevealInterval))
            guard !Task.isCancelled, !submitted else { return }
            let before = revealed
            withAnimation(.easeOut(duration: 0.7)) {
                store.send(id, .revealNext)
            }
            guard revealed > before else { return }
            Haptics.tick()
            withAnimation(.easeOut(duration: 0.6)) {
                edited += pieces[before]
            }
        }
    }

    private func submit() {
        submitted = true
        let text = Sentences.composeRewrite(editedRevealed: edited, original: pieces.joined(), revealed: revealed)
        store.submitRewrite(id, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        store.route = nil
    }
}
