import ActivityKit
import CalmCore
import Foundation

/// One Live Activity per conversation while it has held messages: a snowflake
/// and the countdown to the soonest one in the Dynamic Island and on the Lock
/// Screen. When the last countdown ends it turns into 「冷静好了」 with an alert,
/// and it ends once nothing is held. Countdowns are in demo-clock time, so the
/// activity gets the real equivalent (`settleUntil` minus the demo offset), the
/// same as the notifications.
final class LiveActivities {
    /// Activity ids by conversation id, and the state each was last given.
    /// `Activity` isn't Sendable, so tasks look it up again by id.
    private var activityIDs: [String: String] = [:]
    private var states: [String: HeldActivityAttributes.ContentState] = [:]

    init() {
        // Activities still running from before a relaunch are picked up again.
        for activity in Activity<HeldActivityAttributes>.activities {
            activityIDs[activity.attributes.conversationID] = activity.id
            states[activity.attributes.conversationID] = activity.content.state
        }
    }

    func sync(_ store: ChatStore, offset: TimeInterval) {
        let held = store.records.values.filter { $0.state.isHeld && $0.state != .scoring && $0.state != .dissolving }
        guard !held.isEmpty else {
            if let id = activityIDs.removeValue(forKey: store.id) {
                states[store.id] = nil
                Task.detached { await activity(id)?.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        let waiting = held.filter { $0.state != .ready }.compactMap(\.settleUntil)
        let state = HeldActivityAttributes.ContentState(
            heldCount: held.count,
            readyAt: waiting.min().map { $0.addingTimeInterval(-offset) }
        )
        // Stale at the countdown's end, so the island shows 「好了」 even if the app is suspended by then.
        let content = ActivityContent(state: state, staleDate: state.readyAt)
        if let id = activityIDs[store.id] {
            let old = states[store.id]
            guard old != state else { return }
            states[store.id] = state
            let becameReady = state.readyAt == nil && old?.readyAt != nil
            let alert = becameReady
                ? AlertConfiguration(title: "冷静好了", body: "给\(store.displayName)的消息可以再看一眼了", sound: .default)
                : nil
            Task.detached { await activity(id)?.update(content, alertConfiguration: alert) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let attributes = HeldActivityAttributes(conversationID: store.id, peerName: store.displayName)
            guard let started = try? Activity.request(attributes: attributes, content: content) else { return }
            activityIDs[store.id] = started.id
            states[store.id] = state
        }
    }
}

private nonisolated func activity(_ id: String) -> Activity<HeldActivityAttributes>? {
    Activity<HeldActivityAttributes>.activities.first { $0.id == id }
}
