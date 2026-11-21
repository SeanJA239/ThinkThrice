import SwiftUI

@main
struct ThinkThriceApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            ConversationListView()
                .environment(app)
        }
    }
}
