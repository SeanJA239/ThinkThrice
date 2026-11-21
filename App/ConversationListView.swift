import SwiftUI

struct ConversationListView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("profileName") private var profileName = "我"
    @State private var showProfile = false
    @State private var query = ""

    /// Pinned conversations first, otherwise in their original order, filtered
    /// by the search box (name or note).
    private var stores: [ChatStore] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return app.stores.enumerated()
            .filter { q.isEmpty || $0.element.displayName.localizedCaseInsensitiveContains(q) || $0.element.peer.name.localizedCaseInsensitiveContains(q) }
            .sorted { ($0.element.pinned ? 0 : 1, $0.offset) < ($1.element.pinned ? 0 : 1, $1.offset) }
            .map(\.element)
    }

    var body: some View {
        NavigationStack {
            List {
                // Our own search field as the first row: the system `.searchable`
                // drawer collapsed the large 「聊天」 title into a small one.
                Section {
                    SearchField(text: $query)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                Section {
                    ForEach(stores) { store in
                        NavigationLink {
                            ChatScreen(store: store)
                        } label: {
                            ConversationRow(store: store)
                        }
                    }
                } footer: {
                    if stores.isEmpty, !query.isEmpty {
                        Text("没有找到「\(query)」")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
            }
            .listSectionSpacing(12)
            .navigationTitle("聊天")
            .navigationBarTitleDisplayMode(.large)
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

/// 「搜索联系人」 under the 「聊天」 title: a Liquid Glass capsule that filters by name or note.
private struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索联系人", text: $text)
                .focused($focused)
                .submitLabel(.search)
                .accessibilityIdentifier("contactSearch")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
