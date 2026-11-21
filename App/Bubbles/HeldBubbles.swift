import CalmCore
import ExyteChat
import SwiftUI

/// The row for every message. Outgoing messages (they all have a record) use our
/// own bubbles; messages from the other side keep exyte's default bubble.
///
/// Delivered outgoing messages don't use exyte's bubble either: it measures text
/// with UIKit, which comes out narrower than SwiftUI's rendering of full-width
/// punctuation, so near-one-line Chinese messages were cut off with 「…」.
struct CalmMessageCell: View {
    let params: MessageBuilderParameters
    let store: ChatStore

    var body: some View {
        if let record = store.records[params.message.id] {
            Group {
                switch record.state {
                case .delivered:
                    DeliveredBubble(record: record)
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

/// A solid sent bubble. When a held message has just been delivered, it turns
/// from translucent glass to solid inside the bubble.
struct DeliveredBubble: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.chatTheme) private var theme
    let record: CalmMessage
    @State private var solid = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(record.text)
                // .subheadline is 15 pt at the default size, like exyte's bubbles, and scales with Dynamic Type.
                .font(.subheadline)
                .foregroundStyle(solid ? AnyShapeStyle(theme.colors.messageMyText) : AnyShapeStyle(.primary.opacity(0.55)))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 3) {
                Text(time)
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(solid ? AnyShapeStyle(theme.colors.messageMyTimeText) : AnyShapeStyle(.secondary))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.colors.messageMyBG)
                .opacity(solid ? 1 : 0)
        }
        .glassEffect(.regular.tint(.indigo.opacity(solid ? 0 : 0.18)), in: .rect(cornerRadius: 18))
        .frame(maxWidth: 280, alignment: .trailing)
        .onAppear(perform: animateIfJustDelivered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("已送达：\(record.text)，\(time)")
    }

    private var time: String {
        (record.deliveredAt ?? record.createdAt).formatted(date: .omitted, time: .shortened)
    }

    /// Only a message that was held and delivered moments ago animates, so rows
    /// recreated while scrolling don't replay it.
    private func animateIfJustDelivered() {
        guard record.settleUntil != nil, let deliveredAt = record.deliveredAt,
              app.now.timeIntervalSince(deliveredAt) < 1.5, !reduceMotion else { return }
        solid = false
        withAnimation(.easeInOut(duration: 1.2).delay(0.3)) { solid = true }
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
