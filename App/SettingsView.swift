import SwiftUI

/// Settings. The thresholds are live (the same values the demo panel tunes);
/// the notification and privacy switches are saved but not wired up yet.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("notifyWhenReady") private var notifyWhenReady = true
    @AppStorage("notifySound") private var notifySound = true
    @AppStorage("lockHeld") private var lockHeld = false
    @AppStorage("profileName") private var profileName = "我"
    @State private var showDebug = false
    @State private var confirmReset = false

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        InitialAvatar(name: profileName, image: InitialAvatar.me, size: 52)
                        VStack(alignment: .leading) {
                            Text(profileName).font(.headline)
                            Text("ThinkThrice · 三思而后发").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    LabeledContent("夜间时段", value: "\(app.policy.nightStartHour):00 – \(app.policy.nightEndHour):00")
                    LabeledContent("夜间锁定线 \(Int((app.policy.nightThreshold * 100).rounded()))") {
                        Slider(value: $app.policy.nightThreshold, in: 0.2...0.9, step: 0.05)
                    }
                    LabeledContent("白天锁定线 \(Int((app.policy.dayThreshold * 100).rounded()))") {
                        Slider(value: $app.policy.dayThreshold, in: 0.2...0.9, step: 0.05)
                    }
                    LabeledContent("白天沉淀", value: "\(Int(app.policy.daySettleDuration / 60)) 分钟")
                    LabeledContent("夜间沉淀到", value: "次日 \(app.policy.morningReleaseHour):00")
                    LabeledContent("仪式题数", value: "夜间 \(app.policy.nightRitualQuestions) · 白天 \(app.policy.dayRitualQuestions)")
                } header: {
                    Text("三思规则")
                } footer: {
                    Text("冲动指数达到锁定线就会先冻住，越低越严格，默认 60。辱骂、怼老板和深夜想复合的关键词不看锁定线，一律先冻住。")
                }

                Section("提醒") {
                    Toggle("沉淀好了时通知我", isOn: $notifyWhenReady)
                    Toggle("提示音", isOn: $notifySound)
                }

                Section {
                    Toggle("查看沉淀消息需要 Face ID", isOn: $lockHeld)
                    Label("冻住的消息只存在这台手机上，送达前不会发给任何人。", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("隐私")
                }

                Section("数据") {
                    if app.stats.seededExample {
                        Button("清除示例统计") { app.stats.clearExample() }
                    }
                    Button("清空所有对话", role: .destructive) { confirmReset = true }
                }

                Section("演示") {
                    Button("打开演示面板") { showDebug = true }
                }

                Section {
                    LabeledContent("版本", value: "0.1")
                    LabeledContent("项目", value: "CPX 黑客松 · 赛道 2")
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showDebug) { DebugClockPanel() }
            .confirmationDialog("清空所有对话？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("清空并重新开始", role: .destructive) { app.resetAll() }
            } message: {
                Text("删除所有消息和沉淀状态，演示时钟、锁定线和统计也恢复默认。")
            }
        }
    }
}
