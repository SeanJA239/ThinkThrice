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
                Section("演示时钟") {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        LabeledContent("现在", value: app.now.formatted(date: .abbreviated, time: .standard))
                    }
                    LabeledContent("时段", value: app.policy.isNight(app.now) ? "夜间" : "白天")
                    Button("跳到 01:30（深夜）") { app.jumpClock(toNextHour: 1, minute: 30) }
                    Button("快进到 09:00（早上）") { app.jumpClock(toNextHour: 9) }
                    Button("快进 15 分钟") { app.advanceClock(by: 15 * 60) }
                    Button("回到真实时间", role: .destructive) { app.resetClock() }
                }

                Section("锁定线（冲动指数 ≥ 锁定线就冷静）") {
                    LabeledContent("夜间 \(Int((app.policy.nightThreshold * 100).rounded()))") {
                        Slider(value: $app.policy.nightThreshold, in: 0...1, step: 0.05)
                    }
                    LabeledContent("白天 \(Int((app.policy.dayThreshold * 100).rounded()))") {
                        Slider(value: $app.policy.dayThreshold, in: 0...1, step: 0.05)
                    }
                }

                Section {
                    Picker("模式", selection: Binding(
                        get: { app.p2pRole?.rawValue ?? "off" },
                        set: { app.p2pRole = P2PTransport.Role(rawValue: $0) }
                    )) {
                        Text("关闭").tag("off")
                        Text("等待连接").tag(P2PTransport.Role.host.rawValue)
                        Text("加入").tag(P2PTransport.Role.join.rawValue)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("双机直连")
                } footer: {
                    Text("两台手机都打开 App，一台选「等待连接」，另一台选「加入」，然后都进入列表里的「附近的 TA」。连不上就选「关闭」，回到预设对话演示。")
                }

                Section {
                    Button("清空所有对话", role: .destructive) { confirmReset = true }
                        .confirmationDialog("清空所有对话？", isPresented: $confirmReset, titleVisibility: .visible) {
                            Button("清空并重新开始", role: .destructive) {
                                app.resetAll()
                                dismiss()
                            }
                        } message: {
                            Text("删除所有消息和冷静状态，演示时钟和阈值也恢复默认。")
                        }
                } header: {
                    Text("彩排")
                }

                Section {
                    LabeledContent("模型", value: app.judge.modelName)
                    LabeledContent("中文 BERT 资源", value: app.embeddingStatus)
                    Picker("发给", selection: $probeRecipient) {
                        Text("前任").tag(Recipient.ex)
                        Text("老板").tag(Recipient.boss)
                        Text("其他").tag(Recipient.other)
                    }
                    .pickerStyle(.segmented)
                    TextField("输入一句话试试", text: $probe, axis: .vertical)
                    if !probe.isEmpty {
                        let night = app.policy.isNight(app.now)
                        let verdict = app.judge.judge(probe, to: probeRecipient, lateNight: night)
                        LabeledContent("模型概率", value: app.judge.modelProbability(probe).formatted(.number.precision(.fractionLength(2))))
                        LabeledContent("冲动指数", value: "\(Int(verdict.score.rounded()))")
                        LabeledContent("现在会", value: app.policy.shouldSettle(score: verdict.impulse, at: app.now) ? "冷静" : "直接送达")
                        LabeledContent("原因", value: verdict.reason.rawValue)
                        LabeledContent("命中规则", value: verdict.matched.isEmpty ? "无" : verdict.matched.joined(separator: "、"))
                    }
                } header: {
                    Text("打分器")
                } footer: {
                    Text("按当前演示时钟判断是否深夜。规则在 CalmCore/Sources/CalmCore/ThinkThriceRules.swift。")
                }
            }
            .navigationTitle("演示面板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
