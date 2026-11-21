import CalmCore
import Foundation
import LocalAuthentication
import NaturalLanguage
import Observation

/// App-wide services: the demo clock, the time policy, the detector, the copy and the conversations.
@Observable
final class AppModel {
    /// The app always reads time from the demo clock; with no offset it is real time.
    let clock = DemoClock()
    var policy = TimePolicy() {
        didSet { DemoSettings.thresholds = (policy.nightThreshold, policy.dayThreshold) }
    }
    /// The model side's detector: the Core ML model (ThinkThriceAnger, or the
    /// Lite fallback) plus their keyword rules. Without a model the rules decide alone.
    let judge: ThinkThriceJudge
    let content: Content
    let notifications = Notifications()
    let liveActivities = LiveActivities()
    /// Whether the Chinese BERT embedding the main model runs on is on this device.
    /// Workaround: the assets are missing on a device that has never used them,
    /// and until they are downloaded the main model gives no prediction (the
    /// judge falls back to the Lite model meanwhile). The app asks for them at
    /// launch, and the demo panel shows this before going on stage.
    private(set) var embeddingStatus = "检查中…"

    private func prepareEmbeddingAssets() {
        guard let embedding = NLContextualEmbedding(language: .simplifiedChinese) else {
            embeddingStatus = "系统不支持"
            return
        }
        guard !embedding.hasAvailableAssets else {
            embeddingStatus = "已就绪"
            return
        }
        embeddingStatus = "下载中…"
        Task { [weak self] in
            let result = try? await embedding.requestAssets()
            self?.embeddingStatus = result == .available ? "已就绪" : "未就绪，模型可能只靠规则"
        }
    }

    /// 设置 → 查看冷静中的消息需要 Face ID. While on, held messages are blurred
    /// until Face ID (or the passcode) unlocks them; the unlock lasts until the
    /// app goes to the background.
    var lockHeld: Bool {
        didSet {
            UserDefaults.standard.set(lockHeld, forKey: Self.lockHeldKey)
            heldUnlocked = false
        }
    }
    var heldUnlocked = false
    var hidesHeld: Bool { lockHeld && !heldUnlocked }
    private static let lockHeldKey = "lockHeld"

    /// Asks for Face ID, falling back to the passcode. Returns whether held messages are now visible.
    func unlockHeld() async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // Fallback: a phone with neither Face ID nor a passcode has nothing
            // to unlock with, so the messages open rather than staying stuck.
            heldUnlocked = true
            return true
        }
        heldUnlocked = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "查看冷静中的消息")) ?? false
        return heldUnlocked
    }

    /// The 「三思」 progress log.
    let stats: StatsStore
    private(set) var stores: [ChatStore] = []
    /// Bumped on every demo clock change so views that show the time refresh at once.
    private(set) var clockRevision = 0

    init() {
        // UI tests start every run from the seed conversations and default settings.
        if ProcessInfo.processInfo.environment["THINKTHRICE_RESET"] == "1" {
            ConversationArchive.deleteAll()
            DemoSettings.reset()
            DemoSettings.p2pRole = nil
            UserDefaults.standard.removeObject(forKey: Self.lockHeldKey)
        }
        lockHeld = UserDefaults.standard.bool(forKey: Self.lockHeldKey)
        let classifier = ThinkThriceClassifier()
        // The Lite model also stands in when the main one gives no prediction (see `ThinkThriceJudge.fallback`).
        let lite = classifier?.modelName == "ThinkThriceAngerLite" ? nil : Bundle.main
            .url(forResource: "ThinkThriceAngerLite", withExtension: "mlmodelc")
            .flatMap { try? ThinkThriceClassifier(compiledModelURL: $0) }
        judge = ThinkThriceJudge(classifier: classifier, fallback: lite)
        // Warm up off the main thread so the first message isn't slow.
        Task.detached {
            classifier?.warmUp()
            lite?.warmUp()
        }
        content = Content.load()
        stats = StatsStore(now: Date())
        if let thresholds = DemoSettings.thresholds {
            policy.nightThreshold = thresholds.night
            policy.dayThreshold = thresholds.day
        }
        if DemoSettings.clockOffset != 0 {
            clock.advance(by: DemoSettings.clockOffset)
        }
        p2pRole = DemoSettings.p2pRole
        buildStores()
        startTicking()
        prepareEmbeddingAssets()
    }

    /// The two-phone conversation, listed after the scripted ones while a role is set.
    static let nearbyConversation = Content.Conversation(id: "nearby", name: "附近的 TA", recipient: .other, seed: [], replies: [])

    /// nil: scripted conversations only. Otherwise this phone hosts or joins a
    /// two-phone conversation. Switching back to nil is the on-site fallback.
    var p2pRole: P2PTransport.Role? {
        didSet {
            guard p2pRole != oldValue else { return }
            DemoSettings.p2pRole = p2pRole
            buildStores()
        }
    }

    private func buildStores() {
        for store in stores { store.stop() }
        var conversations = content.scripts.conversations.map { ChatStore(conversation: $0, app: self) }
        if let p2pRole {
            conversations.append(ChatStore(conversation: Self.nearbyConversation, app: self, p2pRole: p2pRole))
        }
        stores = conversations
        syncLiveActivities()
    }

    private func syncLiveActivities() {
        for store in stores { liveActivities.sync(store, offset: clock.offsetFromRealTime) }
    }

    /// For rehearsals: deletes every saved conversation and setting and starts the
    /// scripts over. The two-phone role is kept.
    func resetAll() {
        ConversationArchive.deleteAll()
        stats.reset(now: now)
        DemoSettings.reset()
        notifications.cancelAll()
        clock.reset()
        policy = TimePolicy()
        clockRevision += 1
        buildStores()
    }

    var now: Date { clock.now }

    private func startTicking() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tickAll()
            }
        }
    }

    private func tickAll() {
        for store in stores { store.tick() }
    }

    func jumpClock(toNextHour hour: Int, minute: Int = 0) {
        clock.jump(toNextHour: hour, minute: minute)
        clockChanged()
    }

    func advanceClock(by interval: TimeInterval) {
        clock.advance(by: interval)
        clockChanged()
    }

    func resetClock() {
        clock.reset()
        clockChanged()
    }

    private func clockChanged() {
        DemoSettings.clockOffset = clock.offsetFromRealTime
        clockRevision += 1
        tickAll()
        for store in stores { store.rescheduleNotifications() }
        syncLiveActivities()
    }
}
