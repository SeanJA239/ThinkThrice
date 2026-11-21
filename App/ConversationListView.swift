import SwiftUI

struct ConversationListView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("profileName") private var profileName = "我"
    @State private var showProfile = false

    /// Pinned conversations first, otherwise in their original order.
    private var stores: [ChatStore] {
        app.stores.enumerated()
            .sorted { ($0.element.pinned ? 0 : 1, $0.offset) < ($1.element.pinned ? 0 : 1, $1.offset) }
            .map(\.element)
    }

    var body: some View {
        NavigationStack {
            List(stores) { store in
                NavigationLink {
                    ChatScreen(store: store)
                } label: {
                    ConversationRow(store: store)
                }
            }
            .navigationTitle("聊天")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showProfile = true } label: {
                        InitialAvatar(name: profileName, image: InitialAvatar.me, size: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("个人主页")
                }
                // The avatar is its own circle; the shared glass capsule around
                // toolbar items made a second, misaligned outline.
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
        }
        .task { await app.notifications.requestPermission() }
    }
}

/// Avatar, name, last message, time, and a snowflake badge with how many messages are still held.
private struct ConversationRow: View {
    let store: ChatStore

    var body: some View {
        HStack(spacing: 12) {
            InitialAvatar(name: store.peer.name, image: InitialAvatar.image(for: store))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(store.displayName).font(.headline)
                    if store.muted {
                        Image(systemName: "bell.slash.fill").font(.caption).foregroundStyle(.secondary)
                    }
                    if store.pinned {
                        Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(store.isCooling ? "双方冷静中…" : store.lastMessagePreview)
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
                        .background(Theme.ice.gradient, in: .capsule)
                        .accessibilityLabel("\(store.heldCount) 条沉淀中")
                }
            }
        }
        .padding(.vertical, 4)
    }
}
