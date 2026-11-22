import ActivityKit
import CalmCore
import Foundation

/// One Live Activity per conversation while it has short holds (day settles
/// and the cooling pause, at most `maxHoldDuration`): a snowflake and the
/// countdown to the soonest one in the Dynamic Island and on the Lock Screen.
/// Night holds that last until morning only get the banner notification, so a
/// countdown doesn't sit in the island all night. When the last countdown ends it turns into 「冷静好了」 with an alert,
/// and it ends once nothing is held. Countdowns are in demo-clock time, so the
/// activity gets the real equivalent (`settleUntil` minus the demo offset), the
/// same as the notifications.
final class LiveActivities {
    /// Activity ids by conversation id, and the state each was last given.
    /// `Activity` isn't Sendable, so tasks look it up again by id.
    private var activityIDs: [String: String] = [:]
    private var states: [String: HeldActivityAttributes.ContentState] = [:]

    /// Longer holds get no Live Activity.
    static let maxHoldDuration: TimeInterval = 60 * 60

    init() {
        // Activities outlive the app when it is quit; end the old ones, and
        // `sync` starts fresh ones for whatever is still held.
        for old in Activity<HeldActivityAttributes>.activities {
            let id = old.id
            Task.detached { await activity(id)?.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func sync(_ store: ChatStore, offset: TimeInterval) {
        let held = store.records.values.filter { record in
            guard record.state.isHeld, record.state != .scoring, record.state != .dissolving,
                  let until = record.settleUntil else { return false }
            return until.timeIntervalSince(record.createdAt) <= Self.maxHoldDuration
        }
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
                ? AlertConfiguration(
                    title: LocalizedStringResource(stringLiteral: tr("冷静好了", "Cooled down")),
                    body: LocalizedStringResource(stringLiteral: tr("给\(store.displayName)的消息可以再看一眼了", "Your message to \(store.displayName) is ready for another look")),
                    sound: .default
                )
                : nil
            Task.detached { await activity(id)?.update(content, alertConfiguration: alert) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let attributes = HeldActivityAttributes(conversationID: store.id, peerName: store.displayName, english: AppLanguage.current == .en)
            guard let started = try? Activity.request(attributes: attributes, content: content) else { return }
            activityIDs[store.id] = started.id
            states[store.id] = state
        }
    }
}

private nonisolated func activity(_ id: String) -> Activity<HeldActivityAttributes>? {
    Activity<HeldActivityAttributes>.activities.first { $0.id == id }
}
