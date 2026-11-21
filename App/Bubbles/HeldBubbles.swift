import CalmCore
import ExyteChat
import SwiftUI

/// The row for every message. Times are never drawn inside bubbles: as in
/// iMessage, the newest delivered message gets 「已送达 9:00」 under it, and held
/// messages show their countdown there instead.
///
/// Outgoing messages (they all have a record) use our own bubbles; messages
/// from the other side keep exyte's default bubble. Delivered outgoing messages
/// don't use exyte's bubble either: it measures text with UIKit, which comes out
/// narrower than SwiftUI's rendering of full-width punctuation, so near-one-line
/// Chinese messages were cut off with 「…」.
struct CalmMessageCell: View {
    let params: MessageBuilderParameters
    let store: ChatStore

    var body: some View {
        if let record = store.records[params.message.id] {
            outgoing(record)
        } else {
            params.defaultMessageView()
        }
    }

    @ViewBuilder private func outgoing(_ record: CalmMessage) -> some View {
        Group {
            switch record.state {
            case .delivered:
                DeliveredBubble(record: record, showsStatus: store.lastDeliveredID == record.id)
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
    }
}

/// A small line under an outgoing bubble, like iMessage's 「Read 12:54 AM」: an
/// optional bold word, then the text.
private struct StatusLine: View {
    var emphasis: String?
    let text: String
    var systemImage: String?
    var style: AnyShapeStyle = AnyShapeStyle(.secondary)

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            if let emphasis { Text(emphasis).fontWeight(.semibold) }
            Text(text).contentTransition(.numericText())
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(style)
        .padding(.trailing, 6)
    }
}

/// A solid sent bubble. When a held message has just been delivered, it turns
/// from glass to solid inside the bubble. Only the newest delivered message
/// shows 「已送达」 and its delivery time under it.
struct DeliveredBubble: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.chatTheme) private var theme
    let record: CalmMessage
    let showsStatus: Bool
    @State private var solid = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(record.text)
                // .subheadline is 15 pt at the default size, like exyte's bubbles, and scales with Dynamic Type.
                .font(.subheadline)
                .foregroundStyle(solid ? AnyShapeStyle(theme.colors.messageMyText) : AnyShapeStyle(.primary.opacity(0.55)))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(theme.colors.messageMyBG)
                        .opacity(solid ? 1 : 0)
                }
                .glassEffect(.regular.tint(.cyan.opacity(solid ? 0 : 0.2)), in: .rect(cornerRadius: 18))
            if showsStatus {
                StatusLine(emphasis: "已送达", text: time)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 280, alignment: .trailing)
        .onAppear(perform: animateIfJustDelivered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("我：\(record.text)")
        .accessibilityValue(showsStatus ? "已送达 \(time)" : "")
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

/// A held message: the bubble it would have been, muted and frozen inside a
/// thick Liquid Glass shell. The text can't be selected or copied.
private struct FrozenShell: View {
    @Environment(\.chatTheme) private var theme
    let text: String
    var tint: Color = .cyan

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.disabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(theme.colors.messageMyBG.opacity(0.4), in: .rect(cornerRadius: 18))
            .saturation(0.6)
            .padding(7)
            .glassEffect(.clear.tint(tint.opacity(0.22)).interactive(), in: .rect(cornerRadius: 25))
            .overlay {
                // A bright rim on top and a faint one below make the shell read as thick glass.
                RoundedRectangle(cornerRadius: 25)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.15), tint.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: tint.opacity(0.28), radius: 14, y: 6)
    }
}

/// Frozen while it settles; the countdown sits under the shell.
struct SettlingBubble: View {
    @Environment(AppModel.self) private var app
    let record: CalmMessage

    var body: some View {
        let _ = app.clockRevision
        VStack(alignment: .trailing, spacing: 5) {
            FrozenShell(text: record.text)
            if record.state != .scoring {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    StatusLine(text: countdown, systemImage: "snowflake")
                }
            }
        }
        .frame(maxWidth: 290, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("沉淀中的消息：\(record.text)。\(countdown)")
        .accessibilityHint("轻点选择怎么处理")
        .accessibilityAddTraits(.isButton)
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
        VStack(alignment: .trailing, spacing: 5) {
            FrozenShell(text: record.text, tint: .accentColor)
            StatusLine(text: "沉淀好了 · 轻点确认", systemImage: "checkmark.seal", style: AnyShapeStyle(.tint))
        }
        .frame(maxWidth: 290, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("沉淀好了的消息：\(record.text)")
        .accessibilityHint("轻点确认是否发送")
        .accessibilityAddTraits(.isButton)
    }
}

/// Letting go: the frozen bubble slowly blurs and fades away.
struct DissolveBubble: View {
    static let duration: Duration = .seconds(1.6)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: CalmMessage
    @State private var gone = false

    var body: some View {
        FrozenShell(text: record.text, tint: .gray)
            .frame(maxWidth: 290, alignment: .trailing)
            .blur(radius: gone && !reduceMotion ? 14 : 0)
            .scaleEffect(gone && !reduceMotion ? 0.92 : 1, anchor: .trailing)
            .opacity(gone ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 1.5)) { gone = true }
            }
            .accessibilityHidden(true)
    }
}
