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
                Text("原文正在一句句浮现，你只能改已经出现的部分。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $edited)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                let hidden = pieces.dropFirst(revealed).joined()
                if !hidden.isEmpty {
                    Text(hidden)
                        .foregroundStyle(.secondary)
                        .blur(radius: 6)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular.tint(.gray.opacity(0.2)), in: .rect(cornerRadius: 16))
                        .allowsHitTesting(false)
                        .accessibilityLabel("还有 \(pieces.count - revealed) 句未显出")
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("改写")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        store.send(id, .cancelRewrite)
                        store.route = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("重新判断") { submit() }
                        .disabled(edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitted)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("放下") {
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
            store.send(id, .revealNext)
            guard revealed > before else { return }
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
