import SwiftUI

@main
struct ThinkThriceApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { app.heldUnlocked = false }
                }
        }
    }
}

/// The tabs. A view rather than the scene body, so switching language reliably
/// rebuilds every screen with the new strings; the selected tab stays.
private struct RootView: View {
    @Environment(AppModel.self) private var app
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab(tr("聊天", "Chats"), systemImage: "bubble.left.and.bubble.right.fill", value: 0) {
                ConversationListView()
            }
            Tab(tr("三思", "ThinkThrice"), systemImage: "chart.line.uptrend.xyaxis", value: 1) {
                StatsView()
            }
            Tab(tr("设置", "Settings"), systemImage: "gearshape.fill", value: 2) {
                SettingsView()
            }
        }
        .tint(Theme.brand)
        .id(app.language)
        .environment(\.locale, app.language.locale)
    }
}
