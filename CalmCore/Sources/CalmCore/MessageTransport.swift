import Foundation

/// A text that crossed the transport, in either direction.
public struct WireMessage: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let text: String
    public let sentAt: Date

    public init(id: String = UUID().uuidString, text: String, sentAt: Date) {
        self.id = id
        self.text = text
        self.sentAt = sentAt
    }
}

/// How delivered messages reach the other side and how their replies come back.
///
/// The app only calls `send` for messages in `.delivered`, so held messages never
/// leave the device. The MVP uses `ScriptedTransport`. The optional two-device demo
/// adds a `P2PTransport` built on Network.framework (see docs/HANDOFF.md);
/// `WireMessage` is `Codable` so it can go over the wire as JSON unchanged.
public protocol MessageTransport: AnyObject, Sendable {
    /// Messages from the other side, in arrival order.
    var incoming: AsyncStream<WireMessage> { get }
    func send(_ message: WireMessage) async
}

/// A scripted other side: each delivered message is answered with the next line
/// of the script after a short delay. When the script runs out, it stays silent.
public final class ScriptedTransport: MessageTransport, @unchecked Sendable {
    // @unchecked Sendable: `nextLine` is only touched under `lock`; the continuation is thread-safe.
    public let incoming: AsyncStream<WireMessage>
    private let continuation: AsyncStream<WireMessage>.Continuation
    private let replies: [String]
    private let replyDelay: Duration
    private let clock: any CalmClock
    private let lock = NSLock()
    private var nextLine = 0

    public init(replies: [String], replyDelay: Duration = .seconds(1.5), clock: any CalmClock = SystemClock()) {
        (incoming, continuation) = AsyncStream.makeStream(of: WireMessage.self)
        self.replies = replies
        self.replyDelay = replyDelay
        self.clock = clock
    }

    deinit {
        continuation.finish()
    }

    public func send(_ message: WireMessage) async {
        guard let reply = takeNextLine() else { return }
        try? await Task.sleep(for: replyDelay)
        continuation.yield(WireMessage(text: reply, sentAt: clock.now))
    }

    private func takeNextLine() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard nextLine < replies.count else { return nil }
        defer { nextLine += 1 }
        return replies[nextLine]
    }
}
