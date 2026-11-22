import ActivityKit
import Foundation

/// The Live Activity for messages held in one conversation, shared by the app
/// (which starts and updates it) and the widget extension (which draws it in the
/// Dynamic Island and on the Lock Screen). It never carries message text.
nonisolated struct HeldActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var heldCount: Int
        /// Real time when the soonest held message is ready; nil once all of them are.
        var readyAt: Date?
    }

    var conversationID: String
    var peerName: String
    /// The app's language when the activity started; the widget has no access to the setting.
    var english = false
}
