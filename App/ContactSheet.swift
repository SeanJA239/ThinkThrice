import SwiftUI

/// The contact's detail page, opened by tapping the chat header capsule.
/// The status, note, mute and pin are saved with the conversation; calls,
/// video and search are front end only in this build.
struct ContactSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: ChatStore
    @State private var notAvailable: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        InitialAvatar(name: store.peer.name, size: 88)
                        Text(store.displayName).font(.title2.weight(.semibold))
                        if !store.note.isEmpty {
                            Text(store.peer.name).font(.subheadline).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 14) {
                            action("电话", "phone.fill") { notAvailable = "电话" }
                            action("视频", "video.fill") { notAvailable = "视频通话" }
                            action("搜索", "magnifyingglass") { notAvailable = "搜索聊天记录" }
                            action(store.muted ? "已静音" : "静音", store.muted ? "bell.slash.fill" : "bell.fill") { store.muted.toggle() }
                        }
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker("我对 TA 显示", selection: $store.myStatus) {
                        ForEach(ChatStore.MyStatus.allCases) { status in
                            Label(status.label, systemImage: status.symbol).tag(status)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("我对 TA 显示的状态")
                } footer: {
                    Text("只有 TA 能看到。「冷静中」会告诉对方你在整理情绪，晚点再回复。")
                }

                Section {
                    Button {
                        dismiss()
                        if store.isCooling { store.endCooling() } else { store.startCooling() }
                    } label: {
                        Label(store.isCooling ? "结束冷静" : "双方冷静 15 分钟", systemImage: "snowflake")
                    }
                    LabeledContent("沉淀中的消息", value: "\(store.heldCount) 条")
                }

                Section("设置") {
                    LabeledContent("备注") {
                        TextField(store.peer.name, text: $store.note)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("消息免打扰", isOn: $store.muted)
                    Toggle("置顶聊天", isOn: $store.pinned)
                    LabeledContent("电话", value: "未提供")
                    NavigationLink("共享的媒体") {
                        ContentUnavailableView("还没有共享的媒体", systemImage: "photo.on.rectangle", description: Text("ThinkThrice 目前只发送文字。"))
                    }
                }
            }
            .navigationTitle("联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("\(notAvailable ?? "")暂未开放", isPresented: Binding(get: { notAvailable != nil }, set: { if !$0 { notAvailable = nil } })) {
                Button("好") {}
            } message: {
                Text("演示版只做了界面。")
            }
        }
        .presentationDetents([.large])
    }

    private func action(_ title: String, _ icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 52, height: 40)
                Text(title).font(.caption2)
            }
            .frame(width: 66, height: 64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.brand)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .accessibilityLabel(title)
    }
}
