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
            Text(tr("这条消息正在冷静", "This message is cooling down"))
                .font(.title3.weight(.semibold))
            Text(tr("对方还看不到它。你想怎么处理？", "They can't see it yet. What do you want to do?"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let reason {
                Label(reason, systemImage: "snowflake")
                    .font(.footnote)
                    .foregroundStyle(.cyan)
            }

            exit(night ? tr("当晚就要发", "Send it tonight") : tr("现在就要发", "Send it now"), detail: tr("先看完 \(app.policy.ritualQuestionCount(at: app.now)) 个问题", "After \(app.policy.ritualQuestionCount(at: app.now)) questions first"), icon: "flame") {
                store.send(id, .startRitual)
                store.route = .ritual(id)
            }
            exit(night ? tr("等到早上", "Wait until morning") : tr("等它冷静下来", "Let it cool down"), detail: night ? tr("明早 9:00 提醒你再看一眼", "You'll be reminded at 9:00 tomorrow") : tr("大约 15 分钟后提醒你", "You'll be reminded in about 15 minutes"), icon: "moon.zzz") {
                store.route = nil
            }
            exit(tr("改写", "Rewrite"), detail: tr("原文会一句一句浮现，改完重新判断", "The original thaws one sentence at a time; it is judged again after you edit"), icon: "pencil.and.scribble") {
                store.send(id, .startRewrite)
                store.route = .melt(id)
            }
            exit(tr("放下", "Let go"), detail: tr("让它消散，不留痕迹", "Let it fade without a trace"), icon: "wind") {
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
        guard !verdict.matched.isEmpty else { return tr("冲动指数 \(value) · 语气激动", "Impulse \(value) · heated tone") }
        let words = verdict.matched.prefix(3).map { "「\($0)」" }.joined(separator: " ")
        return tr("冲动指数 \(value) · \(Self.label(verdict.reason)) \(words)", "Impulse \(value) · \(Self.label(verdict.reason)) \(words)")
    }

    private static func label(_ reason: LockReason) -> String {
        switch reason {
        case .insult: tr("狠话", "Harsh words")
        case .bossRant: tr("怼老板", "Ranting at the boss")
        case .reconcile: tr("深夜想复合", "Late-night make-up")
        case .quit: tr("深夜想辞职", "Late-night quitting")
        case .model, .none: tr("语气激动", "Heated tone")
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
