import CalmCore
import ExyteChat
import SwiftUI

/// The row for every message, iMessage style: consecutive messages from one
/// sender sit close together and the last one in the run gets a tail. Times are
/// never drawn inside bubbles: the newest delivered message gets 「已送达 9:00」
/// under it, and held messages show their countdown there instead.
///
/// Every row uses our own bubbles rather than exyte's default one, which
/// measures text with UIKit and cut off near-one-line Chinese messages with 「…」.
struct CalmMessageCell: View {
    let params: MessageBuilderParameters
    let store: ChatStore

    var body: some View {
        let position = store.groupPosition(of: params.message.id)
        Group {
            if let record = store.records[params.message.id] {
                outgoing(record, hasTail: position.isLast)
            } else {
                MessageBubble(text: params.message.text, isMe: false, hasTail: position.isLast)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("\(params.message.user.name)：\(params.message.text)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, position.isFirst ? 10 : 1)
        .padding(.bottom, 1)
    }

    @ViewBuilder private func outgoing(_ record: CalmMessage, hasTail: Bool) -> some View {
        Group {
            switch record.state {
            case .delivered:
                DeliveredBubble(record: record, hasTail: hasTail, showsStatus: store.lastDeliveredID == record.id)
            case .ready:
                ReadyBubble(record: record)
            case .dissolving, .dissolved:
                DissolveBubble(record: record)
            default:
                SettlingBubble(record: record)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(.rect)
        .onTapGesture { store.tap(record.id) }
    }
}

/// An iMessage bubble outline. With a tail, the bottom corner on the sender's
/// side sweeps out into a point; the body always leaves `tailWidth` free on
/// that side so bubbles with and without a tail line up.
nonisolated struct BubbleShape: Shape {
    static let tailWidth: CGFloat = 5
    var isMe: Bool
    var hasTail: Bool

    func path(in rect: CGRect) -> Path {
        // Drawn with the tail on the left (received), then mirrored for sent messages.
        let r = min(18, rect.height / 2)
        let bodyMinX = rect.minX + Self.tailWidth
        var path = Path()
        if hasTail {
            path.move(to: CGPoint(x: bodyMinX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
            // The tail: the bottom edge dips up into a small notch, sweeps out to
            // the tip, then curves back up into the side, like iMessage.
            let x = rect.minX, y = rect.maxY
            path.addLine(to: CGPoint(x: x + 25, y: y))
            path.addCurve(to: CGPoint(x: x + 12, y: y - 4), control1: CGPoint(x: x + 21, y: y), control2: CGPoint(x: x + 17, y: y))
            path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x + 9, y: y - 1), control2: CGPoint(x: x + 4, y: y + 0.5))
            path.addCurve(to: CGPoint(x: bodyMinX, y: y - 11), control1: CGPoint(x: x, y: y), control2: CGPoint(x: bodyMinX, y: y - 1))
            path.addLine(to: CGPoint(x: bodyMinX, y: rect.minY + r))
            path.addArc(tangent1End: CGPoint(x: bodyMinX, y: rect.minY), tangent2End: CGPoint(x: bodyMinX + r, y: rect.minY), radius: r)
            path.closeSubpath()
        } else {
            let body = CGRect(x: bodyMinX, y: rect.minY, width: rect.width - Self.tailWidth, height: rect.height)
            path.addRoundedRect(in: body, cornerSize: CGSize(width: r, height: r), style: .continuous)
        }
        guard isMe else { return path }
        return path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.minX + rect.maxX, ty: 0))
    }
}

/// A plain bubble: system blue for my messages, system gray for theirs.
struct MessageBubble: View {
    let text: String
    let isMe: Bool
    let hasTail: Bool

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isMe ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .padding(isMe ? .trailing : .leading, BubbleShape.tailWidth)
            .background(isMe ? Color.blue : Color(.systemGray5), in: BubbleShape(isMe: isMe, hasTail: hasTail))
            .frame(maxWidth: 290, alignment: isMe ? .trailing : .leading)
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

/// A sent bubble. When a held message has just been delivered, it turns from
/// glass to solid blue in place. Only the newest delivered message shows
/// 「已送达」 and its delivery time under it.
struct DeliveredBubble: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: CalmMessage
    let hasTail: Bool
    let showsStatus: Bool
    @State private var solid = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(record.text)
                .font(.body)
                .foregroundStyle(solid ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.55)))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .padding(.trailing, BubbleShape.tailWidth)
                .background {
                    BubbleShape(isMe: true, hasTail: hasTail)
                        .fill(Color.blue)
                        .opacity(solid ? 1 : 0)
                }
                .glassEffect(.regular.tint(.cyan.opacity(solid ? 0 : 0.2)), in: BubbleShape(isMe: true, hasTail: hasTail))
            if showsStatus {
                StatusLine(emphasis: "已送达", text: time)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 290, alignment: .trailing)
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
    let text: String
    var tint: Color = .cyan

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.disabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.blue.opacity(0.4), in: .rect(cornerRadius: 18, style: .continuous))
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
