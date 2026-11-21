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
            // Always dark, like the Watch's Breathe screen, so the petals glow.
            .environment(\.colorScheme, .dark)
            .presentationBackground(Color(red: 0.03, green: 0.03, blue: 0.08))
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

/// One slow breath per page, like the Apple Watch Breathe app: six translucent
/// petals bloom outward and turn while breathing in, then fold back to a small
/// bud while breathing out. 「下一题」 unlocks after the page's wait.
private struct BreathingGuide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let start: Date
    let wait: TimeInterval
    let unlocked: Bool

    private static let petals = 6

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSince(start)
            // A full breath takes `wait` seconds: in for the first half, out for the second.
            let phase = t.truncatingRemainder(dividingBy: wait) / wait
            let breath = reduceMotion ? 1 : (1 - cos(phase * 2 * .pi)) / 2
            VStack(spacing: 18) {
                ZStack {
                    ForEach(0..<Self.petals, id: \.self) { i in
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.95, blue: 0.85), Color(red: 0.25, green: 0.6, blue: 0.75)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 76, height: 76)
                            .offset(y: -38 * breath)
                            .rotationEffect(.degrees(Double(i) * 360 / Double(Self.petals)))
                            .opacity(0.55)
                            .blendMode(.plusLighter)
                    }
                }
                .scaleEffect(0.45 + 0.55 * breath)
                .rotationEffect(.degrees(60 * breath))
                .frame(width: 170, height: 170)
                Text(unlocked ? "可以继续了" : (phase < 0.5 ? "吸气…" : "呼气…"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.opacity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked ? "可以继续了" : "跟着花瓣慢慢呼吸")
    }
}
