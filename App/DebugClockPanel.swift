import CalmCore
import SwiftUI

/// Hidden demo panel (triple-tap the chat title): move the demo clock, tune the
/// thresholds on site and try sentences against the live scorer.
struct DebugClockPanel: View {
    @Environment(AppModel.self) private var app
    @State private var probe = ""

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section("演示时钟") {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let _ = app.clockRevision
                        LabeledContent("现在", value: app.now.formatted(date: .abbreviated, time: .standard))
                    }
                    LabeledContent("时段", value: app.policy.isNight(app.now) ? "夜间" : "白天")
                    Button("跳到 01:30（深夜）") { app.jumpClock(toNextHour: 1, minute: 30) }
                    Button("快进到 09:00（早上）") { app.jumpClock(toNextHour: 9) }
                    Button("快进 15 分钟") { app.advanceClock(by: 15 * 60) }
                    Button("回到真实时间", role: .destructive) { app.resetClock() }
                }

                Section("阈值（分数 ≥ 阈值就沉淀）") {
                    LabeledContent("夜间 \(app.policy.nightThreshold.formatted(.number.precision(.fractionLength(2))))") {
                        Slider(value: $app.policy.nightThreshold, in: 0...1, step: 0.05)
                    }
                    LabeledContent("白天 \(app.policy.dayThreshold.formatted(.number.precision(.fractionLength(2))))") {
                        Slider(value: $app.policy.dayThreshold, in: 0...1, step: 0.05)
                    }
                }

                Section("打分器") {
                    LabeledContent("当前", value: app.scorerName)
                    TextField("输入一句话试试", text: $probe, axis: .vertical)
                    if !probe.isEmpty {
                        let score = app.scorer.score(probe)
                        LabeledContent("分数", value: score.formatted(.number.precision(.fractionLength(3))))
                        LabeledContent("现在会", value: app.policy.shouldSettle(score: score, at: app.now) ? "沉淀" : "直接送达")
                    }
                }
            }
            .navigationTitle("演示面板")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
