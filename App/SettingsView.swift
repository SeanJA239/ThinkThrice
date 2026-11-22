import SwiftUI

/// Settings. The thresholds are live (the same values the demo panel tunes) and
/// the Face ID switch locks held messages; the notification switches are saved
/// but not wired up yet.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("notifyWhenReady") private var notifyWhenReady = true
    @AppStorage("notifySound") private var notifySound = true
    @AppStorage("profileName") private var profileName = tr("我", "Me")
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
                            Text(tr("ThinkThrice · 三思而后发", "ThinkThrice · think before you send")).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker("语言 / Language", selection: $app.language) {
                        ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("语言 / Language")
                } footer: {
                    Text(tr("冲动检测只认中文，所以聊天内容仍然是中文。", "The impulse detector reads Chinese only, so chats stay in Chinese."))
                }

                Section {
                    LabeledContent(tr("夜间时段", "Night hours"), value: "\(app.policy.nightStartHour):00 – \(app.policy.nightEndHour):00")
                    LabeledContent(tr("夜间锁定线 \(Int((app.policy.nightThreshold * 100).rounded()))", "Night lock line \(Int((app.policy.nightThreshold * 100).rounded()))")) {
                        Slider(value: $app.policy.nightThreshold, in: 0.2...0.9, step: 0.05)
                    }
                    LabeledContent(tr("白天锁定线 \(Int((app.policy.dayThreshold * 100).rounded()))", "Day lock line \(Int((app.policy.dayThreshold * 100).rounded()))")) {
                        Slider(value: $app.policy.dayThreshold, in: 0.2...0.9, step: 0.05)
                    }
                    LabeledContent(tr("白天冷静", "Day cooldown"), value: tr("\(Int(app.policy.daySettleDuration / 60)) 分钟", "\(Int(app.policy.daySettleDuration / 60)) min"))
                    LabeledContent(tr("夜间冷静到", "Night cooldown until"), value: tr("次日 \(app.policy.morningReleaseHour):00", "\(app.policy.morningReleaseHour):00 next day"))
                    LabeledContent(tr("仪式题数", "Ritual questions"), value: tr("夜间 \(app.policy.nightRitualQuestions) · 白天 \(app.policy.dayRitualQuestions)", "Night \(app.policy.nightRitualQuestions) · Day \(app.policy.dayRitualQuestions)"))
                } header: {
                    Text(tr("三思规则", "ThinkThrice rules"))
                } footer: {
                    Text(tr("冲动指数达到锁定线就会先冻住，越低越严格，默认 60。辱骂、怼老板和深夜想复合的关键词不看锁定线，一律先冻住。", "A message whose impulse score reaches the lock line freezes first; lower is stricter, 60 by default. Insults, ranting at the boss and late-night make-up words always freeze, whatever the line."))
                }

                Section(tr("提醒", "Notifications")) {
                    Toggle(tr("冷静好了时通知我", "Notify me when a message cools down"), isOn: $notifyWhenReady)
                    Toggle(tr("提示音", "Sound"), isOn: $notifySound)
                }

                Section {
                    Toggle(tr("查看冷静中的消息需要 Face ID", "Require Face ID to view cooling messages"), isOn: $app.lockHeld)
                    Label(tr("冻住的消息只存在这台手机上，送达前不会发给任何人。", "Frozen messages stay on this phone and reach no one until delivered."), systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(tr("隐私", "Privacy"))
                }

                Section(tr("数据", "Data")) {
                    if app.stats.seededExample {
                        Button(tr("清除示例统计", "Clear example stats")) { app.stats.clearExample() }
                    }
                    Button(tr("清空所有对话", "Clear all chats"), role: .destructive) { confirmReset = true }
                }

                Section(tr("演示", "Demo")) {
                    Button(tr("打开演示面板", "Open demo panel")) { showDebug = true }
                }

                Section {
                    LabeledContent(tr("版本", "Version"), value: "0.1")
                    LabeledContent(tr("项目", "Project"), value: tr("CPX 黑客松 · 赛道 2", "CPX Hackathon · Track 2"))
                }
            }
            .navigationTitle(tr("设置", "Settings"))
            .sheet(isPresented: $showDebug) { DebugClockPanel() }
            .confirmationDialog(tr("清空所有对话？", "Clear all chats?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(tr("清空并重新开始", "Clear and start over"), role: .destructive) { app.resetAll() }
            } message: {
                Text(tr("删除所有消息和冷静状态，演示时钟、锁定线和统计也恢复默认。", "Deletes every message and cooldown, and resets the demo clock, lock lines and stats."))
            }
        }
    }
}
