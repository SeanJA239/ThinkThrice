import Foundation

/// One event per arrow in the settle state machine.
public enum SettleEvent: Equatable, Sendable {
    /// The scorer returned a score for a freshly sent message.
    case scored(Double)
    /// The clock moved; a settling message becomes ready once its countdown passes.
    case tick
    /// 当晚就要发: start the high-cost ritual.
    case startRitual
    /// The user turned the current ritual page. After the last page the message is delivered.
    case ritualNext
    /// 算了 during the ritual: back to settling.
    case ritualCancel
    /// Tapping a ready bubble opens the light confirm.
    case openConfirm
    case confirmSend
    case confirmCancel
    /// 改写: open the melt editor with the first sentence revealed.
    case startRewrite
    /// The melt editor reveals one more sentence.
    case revealNext
    /// The user submitted the rewritten text; the app scores it and sends `.rescored`.
    case submitRewrite(String)
    case rescored(Double)
    case cancelRewrite
    /// 放下: always allowed while the message is held, with no extra step.
    case letGo
    case dissolveFinished
}

/// The settle state machine as a pure function. Events that do not apply to the
/// current state return the message unchanged.
public func reduce(_ message: CalmMessage, _ event: SettleEvent, now: Date, policy: TimePolicy) -> CalmMessage {
    var m = message

    func held() -> SettleState {
        if let until = m.settleUntil, now >= until { return .ready }
        return .settling
    }

    func deliver() {
        m.state = .delivered
        m.deliveredAt = now
    }

    switch (message.state, event) {
    case (.scoring, .scored(let score)):
        m.lastScore = score
        if policy.shouldSettle(score: score, at: now) {
            m.settleUntil = policy.settleUntil(from: now)
            m.state = .settling
        } else {
            deliver()
        }

    case (.settling, .tick):
        m.state = held()

    case (.settling, .startRitual), (.ready, .startRitual):
        m.state = .ritual(step: 0, total: max(1, policy.ritualQuestionCount(at: now)))

    case (.ritual(let step, let total), .ritualNext):
        if step + 1 >= total {
            deliver()
        } else {
            m.state = .ritual(step: step + 1, total: total)
        }

    case (.ritual, .ritualCancel):
        m.state = held()

    case (.ready, .openConfirm):
        m.state = .confirming

    case (.confirming, .confirmSend):
        deliver()

    case (.confirming, .confirmCancel):
        m.state = .ready

    case (.settling, .startRewrite), (.ready, .startRewrite):
        m.state = .rewriting(revealed: min(1, Sentences.split(m.text).count))

    case (.rewriting(let revealed), .revealNext):
        m.state = .rewriting(revealed: min(revealed + 1, Sentences.split(m.text).count))

    case (.rewriting, .submitRewrite(let text)):
        m.text = text
        m.state = .rescoring

    case (.rewriting, .cancelRewrite):
        m.state = held()

    case (.rescoring, .rescored(let score)):
        m.lastScore = score
        if policy.shouldSettle(score: score, at: now) {
            // Still impulsive: back to settling with the rewritten text; the countdown is not reset.
            m.state = held()
        } else {
            deliver()
        }

    case (.settling, .letGo), (.ready, .letGo), (.ritual, .letGo), (.confirming, .letGo), (.rewriting, .letGo):
        m.state = .dissolving

    case (.dissolving, .dissolveFinished):
        m.state = .dissolved

    default:
        break
    }
    return m
}
