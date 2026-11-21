import SwiftUI

/// The contact card that grows down out of the chat header capsule. It is a
/// glass card, not a sheet: `ChatScreen` places it under the header and caps its
/// height so its bottom stays above the keyboard; it scrolls when that is short.
/// Status, note, mute and pin are saved with the conversation; call, video and
/// search are front end only in this build.
struct ContactPanel: View {
    @Bindable var store: ChatStore
    let maxHeight: CGFloat
    let close: () -> Void
    @State private var notAvailable: String?
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        // One ScrollView, sized to the content and capped at `maxHeight`. Switching
        // between a plain and a scrolling layout would rebuild the note field the
        // moment the keyboard shrinks the space, and drop its focus.
        ScrollView {
            content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : nil)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .accessibilityIdentifier("contactPanel")
        .alert("\(notAvailable ?? "")暂未开放", isPresented: Binding(get: { notAvailable != nil }, set: { if !$0 { notAvailable = nil } })) {
            Button("好") {}
        } message: {
            Text("演示版只做了界面。")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                InitialAvatar(name: store.peer.name, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.displayName).font(.title3.weight(.semibold))
                    Text(store.note.isEmpty ? "沉淀中的消息 \(store.heldCount) 条" : store.peer.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "chevron.up")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("收起")
            }

            HStack(spacing: 10) {
                action("电话", "phone.fill") { notAvailable = "电话" }
                action("视频", "video.fill") { notAvailable = "视频通话" }
                action("搜索", "magnifyingglass") { notAvailable = "搜索聊天记录" }
                action(store.muted ? "已静音" : "静音", store.muted ? "bell.slash.fill" : "bell.fill") { store.muted.toggle() }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("我对 TA 显示").font(.footnote).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(ChatStore.MyStatus.allCases) { status in
                        statusChip(status)
                    }
                }
            }

            Button {
                close()
                if store.isCooling { store.endCooling() } else { store.startCooling() }
            } label: {
                Label(store.isCooling ? "结束冷静" : "双方冷静 15 分钟", systemImage: "snowflake")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)

            VStack(spacing: 0) {
                row {
                    Text("备注")
                    TextField(store.peer.name, text: $store.note)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                }
                Divider()
                row { Toggle("消息免打扰", isOn: $store.muted) }
                Divider()
                row { Toggle("置顶聊天", isOn: $store.pinned) }
            }
            .padding(.horizontal, 14)
            .background(.background.opacity(0.5), in: .rect(cornerRadius: 16))
        }
        .padding(18)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack { content() }
            .frame(minHeight: 44)
    }

    private func statusChip(_ status: ChatStore.MyStatus) -> some View {
        let selected = store.myStatus == status
        return Button { store.myStatus = status } label: {
            Label(status.label, systemImage: status.symbol)
                .labelStyle(.titleOnly)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? .white : .primary)
                .background(selected ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(.background.opacity(0.5)), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func action(_ title: String, _ icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.brand)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .accessibilityLabel(title)
    }
}
