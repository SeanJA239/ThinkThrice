import SwiftUI

struct ConversationListView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List(app.stores) { store in
                NavigationLink {
                    ChatScreen(store: store)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.peer.name).font(.headline)
                        Text(store.lastMessagePreview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("ThinkThrice")
        }
        .task { await app.notifications.requestPermission() }
    }
}
