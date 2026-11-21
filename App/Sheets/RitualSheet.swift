import CalmCore
import SwiftUI

/// The high-cost ritual: one question per page, shown without answers. Each page
/// stays `ritualPageWait` seconds before the button unlocks; there is no swipe
/// paging and no swipe-to-dismiss, only the button and 「算了」.
struct RitualSheet: View {
    @Environment(AppModel.self) private var app
    let store: ChatStore
    let id: String
    @State private var unlocked = false
    @State private var pageShownAt = Date()

    var body: some View {
        if case .ritual(let step, let total)? = store.records[id]?.state {
            let questions = app.content.questions.ritual(total: total)
            VStack(spacing: 28) {
                Text("第 \(step + 1) / \(total) 题")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()
                Text(questions[step])
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                Text("不用回答，想一想就好")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()

                BreathingGuide(start: pageShownAt, wait: app.policy.ritualPageWait, unlocked: unlocked)

                Button {
                    withAnimation { store.send(id, .ritualNext) }
                    if store.records[id]?.state == .delivered { store.route = nil }
                } label: {
                    Text(step + 1 == total ? "仍然发送" : "下一题")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(!unlocked)

                Button("算了") {
                    store.send(id, .ritualCancel)
                    store.route = nil
                }
                .buttonStyle(.glass)
            }
            .padding(28)
            .interactiveDismissDisabled()
            .task(id: step) {
                unlocked = false
                pageShownAt = Date()
                try? await Task.sleep(for: .seconds(app.policy.ritualPageWait))
                if !Task.isCancelled {
                    unlocked = true
                    Haptics.tick()
                }
            }
        }
    }
}

/// One slow breath per page: the circle swells and shrinks while a ring fills
/// over the page's wait. The button below unlocks when the ring closes.
private struct BreathingGuide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let start: Date
    let wait: TimeInterval
    let unlocked: Bool

    var body: some View {
        TimelineView(.animation(paused: unlocked && reduceMotion)) { context in
            let t = context.date.timeIntervalSince(start)
            let progress = min(1, max(0, t / wait))
            // A full breath takes `wait` seconds: in for the first half, out for the second.
            let phase = (t.truncatingRemainder(dividingBy: wait)) / wait
            let breath = reduceMotion ? 0.5 : (1 - cos(phase * 2 * .pi)) / 2
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.cyan.opacity(0.55), .indigo.opacity(0.18)], center: .center, startRadius: 4, endRadius: 70))
                    .frame(width: 120, height: 120)
                    .scaleEffect(0.65 + 0.35 * breath)
                    .blur(radius: 2)
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 3)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                Text(unlocked ? "可以继续了" : (phase < 0.5 ? "吸气" : "呼气"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.8))
                    .contentTransition(.opacity)
            }
        }
        .frame(height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked ? "可以继续了" : "跟着圆圈慢慢呼吸")
    }
}
