import CalmCore
import ExyteChat
import SwiftUI

/// The row for every message: held outgoing messages get the glass bubbles,
/// everything else keeps exyte's default bubble.
struct CalmMessageCell: View {
    let params: MessageBuilderParameters
    let store: ChatStore

    var body: some View {
        if let record = store.records[params.message.id], record.state != .delivered {
            Group {
                switch record.state {
                case .ready:
                    ReadyBubble(record: record)
                case .dissolving, .dissolved:
                    DissolveBubble(record: record)
                default:
                    SettlingBubble(record: record)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .contentShape(.rect)
            .onTapGesture { store.tap(record.id) }
        } else {
            params.defaultMessageView()
        }
    }
}

private struct HeldText: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.primary.opacity(0.55))
            .multilineTextAlignment(.leading)
            .textSelection(.disabled)
    }
}

/// Translucent glass bubble with a countdown. The content never leaves the device.
struct SettlingBubble: View {
    @Environment(AppModel.self) private var app
    let record: CalmMessage

    var body: some View {
        let _ = app.clockRevision
        VStack(alignment: .trailing, spacing: 6) {
            HeldText(text: record.text)
            if record.state != .scoring {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Label(countdown, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(.indigo.opacity(0.18)), in: .rect(cornerRadius: 18))
        .frame(maxWidth: 280, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("沉淀中的消息：\(record.text)。\(countdown)")
        .accessibilityHint("轻点选择怎么处理")
    }

    private var countdown: String {
        guard let until = record.settleUntil else { return "沉淀中" }
        let remaining = max(0, until.timeIntervalSince(app.now))
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) % 3600 / 60
        let seconds = Int(remaining) % 60
        if hours > 0 {
            return "沉淀中 · \(until.formatted(date: .omitted, time: .shortened)) 可发 · 还剩 \(hours) 小时 \(minutes) 分"
        }
        return String(format: "沉淀中 · 还剩 %d:%02d", minutes, seconds)
    }
}

/// The countdown has passed; tapping opens the light confirm.
struct ReadyBubble: View {
    let record: CalmMessage

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HeldText(text: record.text)
            Label("沉淀好了 · 轻点确认", systemImage: "checkmark.seal")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(.accentColor.opacity(0.25)).interactive(), in: .rect(cornerRadius: 18))
        .frame(maxWidth: 280, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点确认是否发送")
    }
}

/// Letting go: the bubble slowly blurs and fades away.
struct DissolveBubble: View {
    static let duration: Duration = .seconds(1.6)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: CalmMessage
    @State private var gone = false

    var body: some View {
        HeldText(text: record.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.tint(.gray.opacity(0.15)), in: .rect(cornerRadius: 18))
            .frame(maxWidth: 280, alignment: .trailing)
            .blur(radius: gone && !reduceMotion ? 14 : 0)
            .scaleEffect(gone && !reduceMotion ? 0.92 : 1, anchor: .trailing)
            .opacity(gone ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 1.5)) { gone = true }
            }
            .accessibilityHidden(true)
    }
}
