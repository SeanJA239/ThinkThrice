import SwiftUI

@main
struct ThinkThriceApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("聊天", systemImage: "bubble.left.and.bubble.right.fill") {
                    ConversationListView()
                }
                Tab("三思", systemImage: "chart.line.uptrend.xyaxis") {
                    StatsView()
                }
                Tab("设置", systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
            .tint(Theme.brand)
            .environment(app)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { app.heldUnlocked = false }
            }
        }
    }
}
