import CalmCore
import Foundation
import Observation

/// App-wide services: the demo clock, the time policy, the scorer, the copy and the conversations.
@Observable
final class AppModel {
    /// The app always reads time from the demo clock; with no offset it is real time.
    let clock = DemoClock()
    var policy = TimePolicy()
    let scorer: any Scorer
    /// Shown in the debug panel so the team can tell which scorer is live.
    let scorerName: String
    let content: Content
    let notifications = Notifications()
    private(set) var stores: [ChatStore] = []
    /// Bumped on every demo clock change so views that show the time refresh at once.
    private(set) var clockRevision = 0

    /// The file name the model side delivers: `App/Model/ImpulseClassifier.mlmodel`.
    static let bundledModelName = "ImpulseClassifier"

    init() {
        if let model = CoreMLScorer(bundledModelNamed: Self.bundledModelName) {
            scorer = model
            scorerName = "Core ML（\(Self.bundledModelName)）"
        } else {
            scorer = MaxScorer([KeywordScorer(), NLTaggerScorer()])
            scorerName = "关键词兜底（未找到模型）"
        }
        content = Content.load()
        stores = content.scripts.conversations.map { ChatStore(conversation: $0, app: self) }
        startTicking()
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
        clockRevision += 1
        tickAll()
        for store in stores { store.rescheduleNotifications() }
    }
}
