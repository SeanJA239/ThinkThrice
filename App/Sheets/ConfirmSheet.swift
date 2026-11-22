import CalmCore
import SwiftUI

/// The light confirm once a settled message is ready: one question, then send.
struct ConfirmSheet: View {
    @Environment(AppModel.self) private var app
    let store: ChatStore
    let id: String

    var body: some View {
        VStack(spacing: 20) {
            Text(app.content.questions.localized.morning)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            if let text = store.records[id]?.text {
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .textSelection(.disabled)
            }

            Button {
                store.send(id, .confirmSend)
                store.route = nil
            } label: {
                Text(tr("发送", "Send")).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)

            HStack {
                Button(tr("再等等", "Wait more")) {
                    store.send(id, .confirmCancel)
                    store.route = nil
                }
                Spacer()
                Button(tr("放下", "Let go")) {
                    store.send(id, .letGo)
                    store.route = nil
                }
            }
            .buttonStyle(.glass)
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
