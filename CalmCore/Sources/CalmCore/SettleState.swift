import Foundation

/// Where one outgoing message is in the settle flow.
///
/// `settleUntil` lives on `CalmMessage`, not in these cases, because the ritual,
/// confirm and rewrite branches all return to settling with the original countdown.
public enum SettleState: Equatable, Hashable, Sendable, Codable {
    /// Waiting for the scorer's result. Never shown to the other side.
    case scoring
    /// Sent to the other side.
    case delivered
    /// Held on this device; the countdown runs until `CalmMessage.settleUntil`.
    case settling
    /// The countdown has passed; tapping the bubble opens the light confirm.
    case ready
    /// The high-cost ritual; `step` is the zero-based question page being shown.
    case ritual(step: Int, total: Int)
    /// The light confirm (one question) after the message is ready.
    case confirming
    /// The melt editor; the first `revealed` sentences of the text are visible and editable.
    case rewriting(revealed: Int)
    /// A rewrite was submitted and is waiting for its new score.
    case rescoring
    /// The user let go; the bubble is fading out.
    case dissolving
    /// Gone. The app removes the message from the conversation.
    case dissolved

    /// True while the message is held on the device and must not be copied.
    public var isHeld: Bool {
        switch self {
        case .delivered, .dissolved:
            false
        case .scoring, .settling, .ready, .ritual, .confirming, .rewriting, .rescoring, .dissolving:
            true
        }
    }
}

/// One outgoing message and its settle state. The reducer only ever changes this value.
public struct CalmMessage: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: String
    /// The text that will be delivered: the original, or the latest rewrite.
    public var text: String
    /// The text as first written, kept for the melt editor and the notification.
    public let originalText: String
    public let createdAt: Date
    public var state: SettleState
    /// Set when the message first settles; never reset by later branches.
    public var settleUntil: Date?
    public var lastScore: Double?
    public var deliveredAt: Date?

    public init(id: String = UUID().uuidString, text: String, createdAt: Date) {
        self.id = id
        self.text = text
        self.originalText = text
        self.createdAt = createdAt
        self.state = .scoring
    }
}
