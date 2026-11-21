import CalmCore
import SwiftUI

/// The four exits from a settling message.
struct ActionPanel: View {
    @Environment(AppModel.self) private var app
    let store: ChatStore
    let id: String

    var body: some View {
        let night = app.policy.isNight(app.now)
        VStack(alignment: .leading, spacing: 12) {
            Text("这条消息正在冷静")
                .font(.title3.weight(.semibold))
            Text("对方还看不到它。你想怎么处理？")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let reason {
                Label(reason, systemImage: "snowflake")
                    .font(.footnote)
                    .foregroundStyle(.cyan)
            }

            exit(night ? "当晚就要发" : "现在就要发", detail: "先看完 \(app.policy.ritualQuestionCount(at: app.now)) 个问题", icon: "flame") {
                store.send(id, .startRitual)
                store.route = .ritual(id)
            }
            exit(night ? "等到早上" : "等它冷静下来", detail: night ? "明早 9:00 提醒你再看一眼" : "大约 15 分钟后提醒你", icon: "moon.zzz") {
                store.route = nil
            }
            exit("改写", detail: "原文会一句一句浮现，改完重新判断", icon: "pencil.and.scribble") {
                store.send(id, .startRewrite)
                store.route = .melt(id)
            }
            exit("放下", detail: "让它消散，不留痕迹", icon: "wind") {
                store.send(id, .letGo)
                store.route = nil
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    /// Why this message was held: its impulse score, and the words that triggered it.
    private var reason: String? {
        guard let record = store.records[id], let score = record.lastScore else { return nil }
        let value = Int((score * 100).rounded())
        let verdict = store.holdReason(for: record)
        guard !verdict.matched.isEmpty else { return "冲动指数 \(value) · 语气激动" }
        let words = verdict.matched.prefix(3).map { "「\($0)」" }.joined(separator: " ")
        return "冲动指数 \(value) · \(Self.label(verdict.reason)) \(words)"
    }

    private static func label(_ reason: LockReason) -> String {
        switch reason {
        case .insult: "狠话"
        case .bossRant: "怼老板"
        case .reconcile: "深夜想复合"
        case .quit: "深夜想辞职"
        case .model, .none: "语气激动"
        }
    }

    private func exit(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}
