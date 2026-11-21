import CalmCore
import ExyteChat
import SwiftUI

struct ChatScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var systemScheme
    @Bindable var store: ChatStore
    @State private var showDebugPanel = false
    @State private var showContact = false
    /// Top of the keyboard in screen coordinates, nil while it is hidden.
    @State private var keyboardTop: CGFloat?
    @State private var confirmCooling = false

    var body: some View {
        let _ = app.clockRevision
        // Night follows the demo clock: the chat turns into a night sky and
        // switches to dark mode, sheets included.
        let night = app.policy.isNight(app.now)
        ChatView(messages: store.messages) { draft in
            store.submit(draft.text)
        } messageBuilder: { params in
            CalmMessageCell(params: params, store: store)
        } inputViewBuilder: { params in
            InputBar(params: params, placeholder: inputPlaceholder)
        }
        // The default long-press menu has Copy; held messages must not be copied.
        .showMessageMenuOnLongPress(false)
        .setAvailableInputs([.text])
        .showDateHeaders(false)
        // Times are shown iMessage style, under the newest delivered message (see CalmMessageCell).
        .showMessageTimeView(false)
        // A clear list so the day or night sky shows behind the messages.
        .chatTheme(colors: .init(mainBG: .clear))
        .background { ChatAtmosphere(night: night, snowing: store.heldCount > 0).ignoresSafeArea() }
        .animation(.easeInOut(duration: 1.2), value: night)
        .overlay(alignment: .top) { banner }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatHeader(store: store)
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.45, bounce: 0.25)) { showContact.toggle() }
                    }
                    // Hidden entry to the demo panel: press and hold the header.
                    .onLongPressGesture(minimumDuration: 0.8) { showDebugPanel = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("轻点查看联系人详情")
            }
            // The header draws its own glass capsule.
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                coolingButton
            }
        }
        .confirmationDialog(store.isCooling ? "提前结束冷静？" : "让这段对话冷静 15 分钟？", isPresented: $confirmCooling, titleVisibility: .visible) {
            if store.isCooling {
                Button("结束冷静") { store.endCooling() }
            } else {
                Button("开始冷静") { store.startCooling() }
            }
        } message: {
            Text(store.isCooling ? "暂停中的回复会立刻出现。" : "15 分钟内，你发的消息会先冻住，对方的回复也先不显示；TA 会看到你「冷静中」。")
        }
        .overlay(alignment: .top) { contactCard }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect { keyboardTop = frame.minY }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardTop = nil
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $store.route) { route in
            Group {
                switch route {
                case .actions(let id): ActionPanel(store: store, id: id).nightSheet(night, otherwise: systemScheme)
                // The ritual is always dark, like the Watch's Breathe screen.
                case .ritual(let id): RitualSheet(store: store, id: id)
                case .confirm(let id): ConfirmSheet(store: store, id: id).nightSheet(night, otherwise: systemScheme)
                case .melt(let id): MeltEditor(store: store, id: id).nightSheet(night, otherwise: systemScheme)
                }
            }
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugClockPanel()
                .environment(\.colorScheme, systemScheme)
        }
        .toolbarColorScheme(night ? .dark : nil, for: .navigationBar)
        .environment(\.colorScheme, night ? .dark : systemScheme)
    }

    /// The contact card grows down out of the header capsule (scaling from the top
    /// centre, where the capsule is) instead of rising as a sheet. Its height is
    /// capped so its bottom stays 12 pt above the keyboard when the keyboard is up.
    private var contactCard: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let bottom = min(frame.maxY, keyboardTop ?? .infinity) - 12
            ZStack(alignment: .top) {
                if showContact {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture(perform: closeContact)
                        .transition(.opacity)
                    ContactPanel(store: store, maxHeight: max(180, bottom - frame.minY - 8), close: closeContact)
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(.scale(scale: 0.2, anchor: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(showContact)
    }

    private func closeContact() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { showContact = false }
    }

    private var inputPlaceholder: String {
        guard store.isCooling, let until = store.coolUntil else { return "写点什么…" }
        return "冷静中，消息会等到 \(until.formatted(date: .omitted, time: .shortened))"
    }

    /// Top right: a snowflake that pauses the conversation for both sides, or the
    /// remaining time while it is paused.
    @ViewBuilder private var coolingButton: some View {
        Button { confirmCooling = true } label: {
            if store.isCooling, let until = store.coolUntil {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let left = max(0, Int(until.timeIntervalSince(app.now)))
                    Label(String(format: "%d:%02d", left / 60, left % 60), systemImage: "snowflake")
                        .monospacedDigit()
                }
            } else {
                Image(systemName: "snowflake")
            }
        }
        .tint(store.isCooling ? Theme.ice : nil)
        .accessibilityLabel(store.isCooling ? "冷静中，轻点提前结束" : "冷静 15 分钟")
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
            InitialAvatar(name: store.peer.name, image: InitialAvatar.image(for: store), size: 32)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(store.displayName)
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
                .foregroundStyle(store.isCooling ? AnyShapeStyle(Theme.ice) : store.peerIsTyping ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .contentTransition(.opacity)
            // While cooling, the countdown needs the room; the demo time would cut it off.
            if app.clock.isShifted, !store.isCooling {
                Text(" · 演示时间 \(app.now.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .lineLimit(1)
    }

    private var statusText: String {
        if store.isCooling, let until = store.coolUntil {
            let left = max(0, Int(until.timeIntervalSince(app.now)))
            return String(format: "双方冷静中 · 还剩 %d:%02d", left / 60, left % 60)
        }
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

extension View {
    /// Sheets don't take the chat's dark mode on their own: at night give them a
    /// night-sky background and dark text explicitly.
    @ViewBuilder func nightSheet(_ night: Bool, otherwise scheme: ColorScheme) -> some View {
        if night {
            environment(\.colorScheme, .dark)
                .presentationBackground(Color(red: 0.07, green: 0.09, blue: 0.22))
        } else {
            environment(\.colorScheme, scheme)
        }
    }
}
