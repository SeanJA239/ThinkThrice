import CalmCore
import Foundation
import Observation

/// App-wide services: the demo clock, the time policy, the scorer, the copy and the conversations.
@Observable
final class AppModel {
    /// The app always reads time from the demo clock; with no offset it is real time.
    let clock = DemoClock()
    var policy = TimePolicy() {
        didSet { DemoSettings.thresholds = (policy.nightThreshold, policy.dayThreshold) }
    }
    let scorer: any Scorer
    /// Shown in the debug panel so the team can tell which scorer is live.
    let scorerName: String
    let content: Content
    let notifications = Notifications()
    private(set) var stores: [ChatStore] = []
    /// Bumped on every demo clock change so views that show the time refresh at once.
    private(set) var clockRevision = 0

    /// Keyword rules from `Resources/Keywords.json`, kept separately so the demo
    /// panel can show which rules a sentence matched.
    let keywords: KeywordScorer

    /// An invalid file stops the app at launch with the reason, like the other
    /// bundled JSON; `swift test` in CalmCore checks the file too.
    private static func loadKeywords() -> KeywordScorer {
        guard let url = Bundle.main.url(forResource: "Keywords", withExtension: "json") else {
            fatalError("Keywords.json is missing from the app bundle")
        }
        do {
            return try KeywordScorer(json: Data(contentsOf: url))
        } catch {
            fatalError("Keywords.json is invalid: \(error)")
        }
    }

    /// The file name the model side delivers: `App/Model/ImpulseClassifier.mlmodel`.
    static let bundledModelName = "ImpulseClassifier"

    init() {
        keywords = Self.loadKeywords()
        // The model only tells anger from calm, so keyword rules always run next to
        // it and the higher score wins.
        if let model = CoreMLScorer(bundledModelNamed: Self.bundledModelName) {
            scorer = MaxScorer([model, keywords])
            scorerName = "Core ML + 关键词（\(keywords.rules.count) 条）"
        } else {
            scorer = MaxScorer([keywords, NLTaggerScorer()])
            scorerName = "关键词（\(keywords.rules.count) 条，未找到模型）"
        }
        content = Content.load()
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
    }

    /// The two-phone conversation, listed after the scripted ones while a role is set.
    static let nearbyConversation = Content.Conversation(id: "nearby", name: "附近的 TA", seed: [], replies: [])

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
    }

    /// For rehearsals: deletes every saved conversation and setting and starts the
    /// scripts over. The two-phone role is kept.
    func resetAll() {
        ConversationArchive.deleteAll()
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
    }
}
