import CalmCore
import ExyteChat
import SwiftUI

struct ChatScreen: View {
    @Environment(AppModel.self) private var app
    @Bindable var store: ChatStore
    @State private var showDebugPanel = false

    var body: some View {
        ChatView(messages: store.messages) { draft in
            store.submit(draft.text)
        } messageBuilder: { params in
            CalmMessageCell(params: params, store: store)
        } inputViewBuilder: { params in
            InputBar(params: params)
        }
        // The default long-press menu has Copy; held messages must not be copied.
        .showMessageMenuOnLongPress(false)
        .setAvailableInputs([.text])
        .showDateHeaders(false)
        .overlay(alignment: .top) { banner }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(store.peer.name).font(.headline)
                    DemoTimeCaption()
                }
                // Hidden entry to the demo clock: triple-tap the title.
                .onTapGesture(count: 3) { showDebugPanel = true }
            }
        }
        .sheet(item: $store.route) { route in
            switch route {
            case .actions(let id): ActionPanel(store: store, id: id)
            case .ritual(let id): RitualSheet(store: store, id: id)
            case .confirm(let id): ConfirmSheet(store: store, id: id)
            case .melt(let id): MeltEditor(store: store, id: id)
            }
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugClockPanel()
        }
    }

    @ViewBuilder private var banner: some View {
        if let text = store.banner {
            Text(text)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Shows the demo time under the title while the demo clock is shifted, so the audience can follow it.
struct DemoTimeCaption: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let _ = app.clockRevision
        if app.clock.isShifted {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text("演示时间 \(app.now.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
