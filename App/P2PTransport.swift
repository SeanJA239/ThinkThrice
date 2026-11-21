import CalmCore
import Foundation
import Network

/// Two phones talking directly, with iOS 26's Network.framework API.
///
/// One phone is the host: it advertises the Bonjour service `_calmchat._tcp`
/// and accepts one connection. The other joins: it browses for the service and
/// connects to the first phone it finds. Messages are `WireMessage` values sent
/// as JSON over TCP. Peer-to-peer Wi-Fi is enabled, so it works without the
/// venue's Wi-Fi. Only delivered messages are ever passed to `send`.
///
/// This needs two real iPhones; the simulator can't do peer-to-peer Wi-Fi.
nonisolated final class P2PTransport: MessageTransport, @unchecked Sendable {
    // @unchecked Sendable: `connection` and `task` are only touched under `lock`;
    // the stream continuations are thread-safe.

    enum Role: String, CaseIterable, Identifiable, Sendable {
        case host
        case join

        var id: String { rawValue }
    }

    enum Status: Equatable, Sendable {
        case searching
        case connected
        case disconnected
    }

    typealias WireCoder = Coder<WireMessage, WireMessage, NetworkJSONCoder>

    static let serviceType = "_calmchat._tcp"

    let incoming: AsyncStream<WireMessage>
    let statusUpdates: AsyncStream<Status>
    private let incomingContinuation: AsyncStream<WireMessage>.Continuation
    private let statusContinuation: AsyncStream<Status>.Continuation
    private let role: Role
    private let lock = NSLock()
    private var connection: NetworkConnection<WireCoder>?
    private var task: Task<Void, Never>?

    init(role: Role) {
        self.role = role
        (incoming, incomingContinuation) = AsyncStream.makeStream(of: WireMessage.self)
        (statusUpdates, statusContinuation) = AsyncStream.makeStream(of: Status.self, bufferingPolicy: .bufferingNewest(1))
        statusContinuation.yield(.searching)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.run()
        }
        lock.withLock { self.task = task }
    }

    /// Stops listening or browsing and drops the connection. The running task
    /// holds the transport, so this must be called when the conversation goes away.
    func stop() {
        lock.withLock { task }?.cancel()
        incomingContinuation.finish()
        statusContinuation.finish()
    }

    func send(_ message: WireMessage) async {
        guard let connection = lock.withLock({ connection }) else { return }
        do {
            try await connection.send(message)
        } catch {
            // The message stays delivered on this phone; the other phone missed it.
            print("P2P send failed: \(error)")
        }
    }

    private static var parameters: NWParametersBuilder<WireCoder> {
        NWParametersBuilder.parameters {
            Coder(WireMessage.self, using: .json) { TCP() }
        }
        .peerToPeerIncluded(true)
    }

    /// Connects, relays messages until the connection drops, then starts over.
    private func run() async {
        while !Task.isCancelled {
            statusContinuation.yield(.searching)
            do {
                switch role {
                case .host: try await host()
                case .join: try await join()
                }
            } catch {
                print("P2P \(role.rawValue) stopped: \(error)")
            }
            lock.withLock { connection = nil }
            guard !Task.isCancelled else { return }
            statusContinuation.yield(.disconnected)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func host() async throws {
        let listener = try NetworkListener(for: .bonjour(type: Self.serviceType), using: Self.parameters)
            .newConnectionLimit(1)
        try await listener.run { [weak self] connection in
            try await self?.relay(connection)
        }
    }

    private func join() async throws {
        let browserParameters = NWParameters()
        browserParameters.includePeerToPeer = true
        let browser = NetworkBrowser(for: .bonjour(Self.serviceType), using: browserParameters)
        let endpoint = try await browser.run { endpoints in
            if let first = endpoints.first { return .finish(first) }
            return .continue
        }
        try await relay(NetworkConnection(to: endpoint, using: Self.parameters))
    }

    private func relay(_ connection: NetworkConnection<WireCoder>) async throws {
        lock.withLock { self.connection = connection }
        statusContinuation.yield(.connected)
        defer {
            lock.withLock { self.connection = nil }
            // The host keeps listening after a drop; the joiner starts over in `run`.
            if !Task.isCancelled { statusContinuation.yield(.searching) }
        }
        for try await (message, _) in connection.messages {
            incomingContinuation.yield(message)
        }
    }
}
