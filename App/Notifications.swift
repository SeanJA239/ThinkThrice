import CalmCore
import Foundation
import UserNotifications

/// The "冷静好了" local notification, one per held message, keyed by message id.
///
/// Settle times are in demo-clock time, so each notification fires at the real
/// equivalent (`settleUntil` minus the demo offset). After the demo clock jumps
/// past a countdown, the notification fires about a second later, and it shows
/// as a banner even while the app is open.
final class Notifications: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func schedule(for record: CalmMessage, peerName: String, clock: DemoClock, policy: TimePolicy) {
        guard let until = record.settleUntil else { return }
        let content = UNMutableNotificationContent()
        content.title = peerName
        content.body = Self.body(for: record, policy: policy)
        content.sound = .default
        let realFireDate = until.addingTimeInterval(-clock.offsetFromRealTime)
        let interval = max(1, realFireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: record.id, content: content, trigger: trigger))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// 「昨晚 1:47 的那条冷静好了」 for night messages, 「14:05 的那条冷静好了」 by day.
    static func body(for record: CalmMessage, policy: TimePolicy) -> String {
        let formatter = DateFormatter()
        formatter.calendar = policy.calendar
        formatter.timeZone = policy.calendar.timeZone
        formatter.dateFormat = "H:mm"
        let time = formatter.string(from: record.createdAt)
        return policy.isNight(record.createdAt) ? "昨晚 \(time) 的那条冷静好了" : "\(time) 的那条冷静好了"
    }

    /// Asked at launch so the first held message can already notify.
    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
