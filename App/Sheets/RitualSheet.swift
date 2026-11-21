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

                ProgressView(timerInterval: pageShownAt...pageShownAt.addingTimeInterval(app.policy.ritualPageWait), countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(.secondary)
                .opacity(unlocked ? 0 : 1)

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
                if !Task.isCancelled { unlocked = true }
            }
        }
    }
}
