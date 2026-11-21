import Foundation

extension Recipient {
    /// Scene factor from the model side's handoff: 前任 2.0, 老板 1.6, everyone else 1.0.
    /// It only scales the model path; a keyword hit locks whatever the factor.
    public var contextFactor: Double {
        switch self {
        case .ex: 2.0
        case .boss: 1.6
        case .other: 1.0
        }
    }
}

/// The model side's detector as the app calls it: the classifier's probability
/// (0 when no model loaded, so only the rules decide) and `ThinkThriceRules`.
public struct ThinkThriceJudge: Sendable {
    public let classifier: ThinkThriceClassifier?

    public init(classifier: ThinkThriceClassifier?) {
        self.classifier = classifier
    }

    /// Shown in the demo panel, so the team can tell which model is live.
    public var modelName: String { classifier?.modelName ?? "未加载，只用规则" }

    public func modelProbability(_ text: String) -> Double {
        classifier?.messageProbability(text) ?? 0
    }

    public func judge(_ text: String, to recipient: Recipient, lateNight: Bool) -> Verdict {
        ThinkThriceRules.judgeMessage(
            text,
            modelProb: modelProbability(text),
            to: recipient,
            lateNight: lateNight,
            contextFactor: recipient.contextFactor
        )
    }
}

extension Verdict {
    /// The verdict's 0–100 score as the 0…1 value the settle state machine
    /// compares with `TimePolicy`'s thresholds. With both thresholds at 0.6 this
    /// locks exactly when `lock` is true: keyword hits score 100, the whitelists
    /// stay below 60, and the model path locks at 60.
    public var impulse: Double { score / 100 }
}
