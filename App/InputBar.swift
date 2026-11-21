import ExyteChat
import SwiftUI

/// Liquid Glass input bar. Sending goes through exyte (`.send`), which clears the
/// field and calls the `didSendMessage` closure where the message is scored.
struct InputBar: View {
    let params: InputViewBuilderParameters

    private var isEmpty: Bool {
        params.text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("写点什么…", text: params.text, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))

                Button {
                    params.inputViewActionClosure(.send)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(isEmpty)
                .accessibilityLabel("发送")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
