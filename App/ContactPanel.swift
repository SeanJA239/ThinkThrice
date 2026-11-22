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
        .tint(Theme.brandOnGlass)
        .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : nil)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .accessibilityIdentifier("contactPanel")
        .alert(tr("\(notAvailable ?? "")暂未开放", "\(notAvailable ?? "") isn't available yet"), isPresented: Binding(get: { notAvailable != nil }, set: { if !$0 { notAvailable = nil } })) {
            Button(tr("好", "OK")) {}
        } message: {
            Text(tr("演示版只做了界面。", "Only the interface is built in this demo."))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                InitialAvatar(name: store.peer.name, image: InitialAvatar.image(for: store), size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.displayName).font(.title3.weight(.semibold))
                    Text(store.note.isEmpty ? tr("冷静中的消息 \(store.heldCount) 条", "\(store.heldCount) \(store.heldCount == 1 ? "message" : "messages") cooling down") : store.conversation.localizedName)
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
                .accessibilityLabel(tr("收起", "Collapse"))
            }

            HStack(spacing: 10) {
                action(tr("电话", "Call"), "phone.fill") { notAvailable = tr("电话", "Call") }
                action(tr("视频", "Video"), "video.fill") { notAvailable = tr("视频通话", "Video call") }
                action(tr("搜索", "Search"), "magnifyingglass") { notAvailable = tr("搜索聊天记录", "Search chat") }
                action(store.muted ? tr("已静音", "Muted") : tr("静音", "Mute"), store.muted ? "bell.slash.fill" : "bell.fill") { store.muted.toggle() }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(tr("我对 TA 显示", "They see me as")).font(.footnote).foregroundStyle(.secondary)
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
                Label(store.isCooling ? tr("结束冷静", "End cooldown") : tr("双方冷静 15 分钟", "Both cool down 15 min"), systemImage: "snowflake")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            // Clear, untinted Liquid Glass, faded so the card shows through more.
            .background { FadedGlass(shape: Capsule(), interactive: true) }

            VStack(spacing: 0) {
                row {
                    Text(tr("备注", "Nickname"))
                    TextField(store.conversation.localizedName, text: $store.note)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                }
                Divider()
                row { Toggle(tr("消息免打扰", "Mute notifications"), isOn: $store.muted) }
                Divider()
                row { Toggle(tr("置顶聊天", "Pin chat"), isOn: $store.pinned) }
            }
            // iOS 26 switches already turn into Liquid Glass while dragged; the
            // group behind them is clear glass too, not a white block.
            .tint(Theme.brand)
            .padding(.horizontal, 14)
            .background { FadedGlass(shape: RoundedRectangle(cornerRadius: 16)) }
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
        .foregroundStyle(Theme.brandOnGlass)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .accessibilityLabel(title)
    }
}

/// Clear Liquid Glass, faded: glass inside the glass card otherwise renders as
/// a near-white block, so its layer is drawn at partial opacity.
private struct FadedGlass<S: Shape>: View {
    let shape: S
    var interactive = false

    var body: some View {
        shape
            .fill(.clear)
            .glassEffect(interactive ? .clear.interactive() : .clear, in: shape)
            .opacity(0.3)
    }
}
