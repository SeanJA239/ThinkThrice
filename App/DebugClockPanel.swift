import CalmCore
import SwiftUI

/// Hidden demo panel (triple-tap the chat header): move the demo clock, tune the
/// thresholds on site, try sentences against the live scorer, switch the
/// two-phone conversation on or off, and wipe everything for a rehearsal.
struct DebugClockPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var probe = ""
    @State private var probeRecipient = Recipient.ex
    @State private var confirmReset = false

    var body: some View {
        @Bindable var app = app
        // Read so the whole panel (for example 时段) refreshes when the demo clock moves.
        let _ = app.clockRevision
        NavigationStack {
            Form {
                Section(tr("演示时钟", "Demo clock")) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        LabeledContent(tr("现在", "Now"), value: app.now.formatted(date: .abbreviated, time: .standard))
                    }
                    LabeledContent(tr("时段", "Period"), value: app.policy.isNight(app.now) ? tr("夜间", "Night") : tr("白天", "Day"))
                    Button(tr("跳到 01:30（深夜）", "Jump to 01:30 (late night)")) { app.jumpClock(toNextHour: 1, minute: 30) }
                    Button(tr("快进到 09:00（早上）", "Skip to 09:00 (morning)")) { app.jumpClock(toNextHour: 9) }
                    Button(tr("快进 15 分钟", "Skip 15 minutes")) { app.advanceClock(by: 15 * 60) }
                    Button(tr("回到真实时间", "Back to real time"), role: .destructive) { app.resetClock() }
                }

                Section(tr("锁定线（冲动指数 ≥ 锁定线就冷静）", "Lock line (impulse score ≥ lock line cools down)")) {
                    LabeledContent(tr("夜间 \(Int((app.policy.nightThreshold * 100).rounded()))", "Night \(Int((app.policy.nightThreshold * 100).rounded()))")) {
                        Slider(value: $app.policy.nightThreshold, in: 0...1, step: 0.05)
                    }
                    LabeledContent(tr("白天 \(Int((app.policy.dayThreshold * 100).rounded()))", "Day \(Int((app.policy.dayThreshold * 100).rounded()))")) {
                        Slider(value: $app.policy.dayThreshold, in: 0...1, step: 0.05)
                    }
                }

                Section {
                    Picker(tr("模式", "Mode"), selection: Binding(
                        get: { app.p2pRole?.rawValue ?? "off" },
                        set: { app.p2pRole = P2PTransport.Role(rawValue: $0) }
                    )) {
                        Text(tr("关闭", "Off")).tag("off")
                        Text(tr("等待连接", "Host")).tag(P2PTransport.Role.host.rawValue)
                        Text(tr("加入", "Join")).tag(P2PTransport.Role.join.rawValue)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(tr("双机直连", "Two phones"))
                } footer: {
                    Text(tr("两台手机都打开 App，一台选「等待连接」，另一台选「加入」，然后都进入列表里的「附近的 TA」。连不上就选「关闭」，回到预设对话演示。", "Open the app on both phones, choose \"Host\" on one and \"Join\" on the other, then open \"Someone nearby\" in the list. If they won't connect, choose \"Off\" and demo with the scripted chats."))
                }

                Section {
                    Button(tr("清空所有对话", "Clear all chats"), role: .destructive) { confirmReset = true }
                        .confirmationDialog(tr("清空所有对话？", "Clear all chats?"), isPresented: $confirmReset, titleVisibility: .visible) {
                            Button(tr("清空并重新开始", "Clear and start over"), role: .destructive) {
                                app.resetAll()
                                dismiss()
                            }
                        } message: {
                            Text(tr("删除所有消息和冷静状态，演示时钟和阈值也恢复默认。", "Deletes every message and cooldown, and resets the demo clock and lock lines."))
                        }
                } header: {
                    Text(tr("彩排", "Rehearsal"))
                }

                Section {
                    LabeledContent(tr("模型", "Model"), value: app.judge.modelName)
                    LabeledContent("中文 BERT 资源", value: app.embeddingState.label)
                    Picker(tr("发给", "To"), selection: $probeRecipient) {
                        Text(tr("前任", "Ex")).tag(Recipient.ex)
                        Text(tr("老板", "Boss")).tag(Recipient.boss)
                        Text(tr("其他", "Other")).tag(Recipient.other)
                    }
                    .pickerStyle(.segmented)
                    TextField(tr("输入一句话试试", "Type a sentence to test"), text: $probe, axis: .vertical)
                    if !probe.isEmpty {
                        let night = app.policy.isNight(app.now)
                        let verdict = app.judge.judge(probe, to: probeRecipient, lateNight: night)
                        LabeledContent(tr("模型概率", "Model probability"), value: app.judge.modelProbability(probe).formatted(.number.precision(.fractionLength(2))))
                        LabeledContent(tr("冲动指数", "Impulse score"), value: "\(Int(verdict.score.rounded()))")
                        LabeledContent(tr("现在会", "Right now it would"), value: app.policy.shouldSettle(score: verdict.impulse, at: app.now) ? tr("冷静", "Cool down") : tr("直接送达", "Deliver"))
                        LabeledContent(tr("原因", "Reason"), value: verdict.reason.rawValue)
                        LabeledContent(tr("命中规则", "Matched words"), value: verdict.matched.isEmpty ? tr("无", "None") : verdict.matched.joined(separator: "、"))
                    }
                } header: {
                    Text(tr("打分器", "Scorer"))
                } footer: {
                    Text(tr("按当前演示时钟判断是否深夜。规则在 CalmCore/Sources/CalmCore/ThinkThriceRules.swift。", "Late night follows the demo clock. Rules are in CalmCore/Sources/CalmCore/ThinkThriceRules.swift."))
                }
            }
            .navigationTitle(tr("演示面板", "Demo panel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("完成", "Done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
