import SwiftUI

struct ConversationListView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List(app.stores) { store in
                NavigationLink {
                    ChatScreen(store: store)
                } label: {
                    ConversationRow(store: store)
                }
            }
            .navigationTitle("ThinkThrice")
        }
        .task { await app.notifications.requestPermission() }
    }
}

/// Avatar, name, last message, time, and a snowflake badge with how many messages are still held.
private struct ConversationRow: View {
    let store: ChatStore

    var body: some View {
        HStack(spacing: 12) {
            Text(String(store.peer.name.prefix(1)))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.indigo.gradient, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.peer.name).font(.headline)
                Text(store.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                if let date = store.lastActivity {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if store.heldCount > 0 {
                    Label("\(store.heldCount)", systemImage: "snowflake")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.cyan.gradient, in: .capsule)
                        .accessibilityLabel("\(store.heldCount) 条沉淀中")
                }
            }
        }
        .padding(.vertical, 4)
    }
}
