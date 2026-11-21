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
            .background(isMe ? Theme.brand : Color(.systemGray5), in: BubbleShape(isMe: isMe, hasTail: hasTail))
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
                        .fill(Theme.brand)
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
/// thick Liquid Glass shell. The text can't be selected or copied. With
/// `frozen` false it is a plain blue bubble, so animating `frozen` to true plays
/// the freeze: the colour drains, an icy glint appears and the shell closes around it.
private struct FrozenShell: View {
    let text: String
    var tint: Color = .cyan
    var frozen = true

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.white.opacity(frozen ? 0.9 : 1))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.disabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.brand.opacity(frozen ? 0.4 : 1), in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                // Frost on the inner bubble: a cold glint from the top-left corner.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05), .clear], startPoint: .topLeading, endPoint: .center))
                    .opacity(frozen ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .saturation(frozen ? 0.6 : 1)
            .padding(frozen ? 7 : 0)
            .glassEffect(.clear.tint(tint.opacity(frozen ? 0.22 : 0)).interactive(), in: .rect(cornerRadius: 25))
            .overlay {
                // A bright rim on top and a faint one below make the shell read as thick glass.
                RoundedRectangle(cornerRadius: 25)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.15), tint.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.2
                    )
                    .opacity(frozen ? 1 : 0)
            }
            .shadow(color: tint.opacity(frozen ? 0.28 : 0), radius: 14, y: 6)
    }
}

/// Snowflakes that burst out of a bubble the moment it freezes.
private struct SnowBurst: View {
    @State private var spread = false
    private static let count = 14

    var body: some View {
        ZStack {
            ForEach(0..<Self.count, id: \.self) { i in
                let angle = Double(i) / Double(Self.count) * 2 * .pi + noise(i, 7) * 0.5
                let distance = 50 + noise(i, 8) * 50
                Image(systemName: "snowflake")
                    .font(.system(size: 9 + noise(i, 9) * 9, weight: .semibold))
                    .foregroundStyle(.cyan.opacity(0.9), .white)
                    .rotationEffect(.degrees(spread ? 160 * (noise(i, 10) - 0.5) : 0))
                    .offset(x: spread ? cos(angle) * distance : 0, y: spread ? sin(angle) * distance * 0.6 : 0)
                    .scaleEffect(spread ? 1 : 0.2)
                    .opacity(spread ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { spread = true }
        }
    }
}

/// A small ring that empties as the settle countdown runs out.
private struct CountdownRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0, min(1, 1 - progress)))
                .stroke(.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 11, height: 11)
    }
}

/// Frozen while it settles; the countdown sits under the shell. A message that was
/// just held plays the freeze: it shows as a normal blue bubble first, then frosts
/// over with a burst of snowflakes (the heavy haptic comes from `ChatStore`).
struct SettlingBubble: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: CalmMessage
    @State private var frozen: Bool
    @State private var burst: UUID?
    @State private var pulse = false

    init(record: CalmMessage) {
        self.record = record
        _frozen = State(initialValue: record.state != .scoring)
    }

    var body: some View {
        let _ = app.clockRevision
        VStack(alignment: .trailing, spacing: 5) {
            FrozenShell(text: record.text, frozen: frozen)
                .scaleEffect(pulse ? 1.05 : 1, anchor: .trailing)
                .overlay {
                    if let burst { SnowBurst().id(burst) }
                }
            if record.state != .scoring {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 4) {
                        CountdownRing(progress: progress)
                        StatusLine(text: countdown)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: 290, alignment: .trailing)
        .onChange(of: record.state) { old, new in
            if new == .settling, old == .scoring || old == .rescoring { freeze() }
        }
        .onAppear {
            // exyte may rebuild the row when the state changes; a row that appears
            // already settled moments after it was sent still plays the freeze.
            if record.state == .settling, app.now.timeIntervalSince(record.createdAt) < 1.2 { freeze() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("沉淀中的消息：\(record.text)。\(countdown)")
        .accessibilityHint("轻点选择怎么处理")
        .accessibilityAddTraits(.isButton)
    }

    private func freeze() {
        guard !reduceMotion else {
            frozen = true
            return
        }
        frozen = false
        burst = UUID()
        withAnimation(.spring(duration: 0.25)) { pulse = true }
        withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.12)) {
            frozen = true
            pulse = false
        }
    }

    /// How much of the settle time has passed, 0…1.
    private var progress: Double {
        guard let until = record.settleUntil else { return 0 }
        let total = until.timeIntervalSince(record.createdAt)
        guard total > 0 else { return 1 }
        return app.now.timeIntervalSince(record.createdAt) / total
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

/// Letting go: the frozen bubble breaks into specks of ice that drift up and away.
struct DissolveBubble: View {
    static let duration: Duration = .seconds(1.6)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let record: CalmMessage
    @State private var gone = false
    @State private var start = Date()

    var body: some View {
        FrozenShell(text: record.text, tint: .gray)
            .blur(radius: gone && !reduceMotion ? 10 : 0)
            .scaleEffect(gone && !reduceMotion ? 0.94 : 1, anchor: .trailing)
            .opacity(gone ? 0 : 1)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        IceDust(size: geo.size, start: start)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: 290, alignment: .trailing)
            .onAppear {
                start = Date()
                withAnimation(.easeIn(duration: 0.9)) { gone = true }
            }
            .accessibilityHidden(true)
    }
}

/// Particles spread over the bubble's area that drift up and to the right and fade out.
private struct IceDust: View {
    let size: CGSize
    let start: Date
    private static let count = 70
    private static let life = 1.5

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { canvas, canvasSize in
                for i in 0..<Self.count {
                    // Each speck appears a little later the further right it starts.
                    let delay = noise(i, 1) * 0.35
                    let age = (t - delay) / Self.life
                    guard age > 0, age < 1 else { continue }
                    let eased = 1 - pow(1 - age, 2)
                    let x0 = 40 + noise(i, 2) * size.width
                    let y0 = 40 + noise(i, 3) * size.height
                    let x = x0 + (20 + noise(i, 4) * 50) * eased
                    let y = y0 - (30 + noise(i, 5) * 70) * eased
                    let r = 1 + noise(i, 6) * 2.2
                    let color: Color = noise(i, 7) > 0.5 ? .cyan : .white
                    canvas.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(0.9 * (1 - age))))
                }
            }
            .frame(width: size.width + 80, height: size.height + 80)
            .offset(x: -40, y: -40)
        }
    }
}
