import CalmCore
import ExyteChat
import SwiftUI

struct ChatScreen: View {
    @Environment(AppModel.self) private var app
    @Bindable var store: ChatStore
    @State private var showDebugPanel = false

    var body: some View {
        ChatView(messages: store.messages) { draft in
            store.submit(draft.text)
        } messageBuilder: { params in
            CalmMessageCell(params: params, store: store)
        } inputViewBuilder: { params in
            InputBar(params: params)
        }
        // The default long-press menu has Copy; held messages must not be copied.
        .showMessageMenuOnLongPress(false)
        .setAvailableInputs([.text])
        .showDateHeaders(false)
        // Times are shown iMessage style, under the newest delivered message (see CalmMessageCell).
        .showMessageTimeView(false)
        .overlay(alignment: .top) { banner }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatHeader(store: store)
                    // Hidden entry to the demo clock: triple-tap the header.
                    .onTapGesture(count: 3) { showDebugPanel = true }
            }
            // The header draws its own glass capsule.
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(item: $store.route) { route in
            switch route {
            case .actions(let id): ActionPanel(store: store, id: id)
            case .ritual(let id): RitualSheet(store: store, id: id)
            case .confirm(let id): ConfirmSheet(store: store, id: id)
            case .melt(let id): MeltEditor(store: store, id: id)
            }
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugClockPanel()
        }
    }

    @ViewBuilder private var banner: some View {
        if let text = store.banner {
            Text(text)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// The contact bar: avatar, name and status in a Liquid Glass capsule. The status
/// reads 「在线」, 「正在输入…」 or, for a two-phone conversation, the connection
/// state, plus the demo time while the demo clock is shifted.
struct ChatHeader: View {
    @Environment(AppModel.self) private var app
    let store: ChatStore

    var body: some View {
        HStack(spacing: 10) {
            Text(String(store.peer.name.prefix(1)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.indigo.gradient, in: .circle)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(store.peer.name)
                    .font(.subheadline.weight(.semibold))
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    statusLine
                }
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 16)
        .padding(.vertical, 5)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(.capsule)
        .animation(.smooth, value: store.peerIsTyping)
        .animation(.smooth, value: store.presence)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chatHeader")
    }

    @ViewBuilder private var statusLine: some View {
        let _ = app.clockRevision
        HStack(spacing: 0) {
            Text(statusText)
                .foregroundStyle(store.peerIsTyping ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .contentTransition(.opacity)
            if app.clock.isShifted {
                Text(" · 演示时间 \(app.now.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .lineLimit(1)
    }

    private var statusText: String {
        if store.peerIsTyping { return "正在输入…" }
        switch store.presence {
        case .online: return "在线"
        case .searching: return "正在寻找附近的手机…"
        case .disconnected: return "连接断开，正在重连…"
        }
    }

    private var dotColor: Color {
        switch store.presence {
        case .online: .green
        case .searching: .orange
        case .disconnected: .gray
        }
    }
}
