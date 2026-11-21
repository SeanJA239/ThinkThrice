import CalmCore
import ExyteChat
import Foundation
import Observation

/// One conversation. exyte's `Message` is only for display; the settle state of
/// each outgoing message lives in `records`, keyed by message id, and only the
/// CalmCore reducer changes it.
@Observable
final class ChatStore: Identifiable {
    enum Route: Identifiable, Equatable {
        case actions(String)
        case ritual(String)
        case confirm(String)
        case melt(String)

        var id: String {
            switch self {
            case .actions(let id): "actions-\(id)"
            case .ritual(let id): "ritual-\(id)"
            case .confirm(let id): "confirm-\(id)"
            case .melt(let id): "melt-\(id)"
            }
        }
    }

    static let me = User(id: "me", name: "我", avatarURL: nil, isCurrentUser: true)

    let conversation: Content.Conversation
    let peer: User
    private(set) var messages: [Message] = []
    private(set) var records: [String: CalmMessage] = [:]
    var route: Route?
    /// A short line shown over the chat after a rewrite is scored.
    var banner: String?

    private unowned let app: AppModel
    private let transport: any MessageTransport

    var id: String { conversation.id }

    init(conversation: Content.Conversation, app: AppModel) {
        self.conversation = conversation
        self.app = app
        peer = User(id: conversation.id, name: conversation.name, avatarURL: nil, isCurrentUser: false)
        transport = ScriptedTransport(replies: conversation.replies, clock: app.clock)
        let start = app.now.addingTimeInterval(-Double(conversation.seed.count) * 60)
        messages = conversation.seed.enumerated().map { index, text in
            Message(id: UUID().uuidString, user: peer, createdAt: start.addingTimeInterval(Double(index) * 60), text: text)
        }
        listen()
    }

    var lastMessagePreview: String {
        guard let last = messages.last else { return "" }
        if let record = records[last.id], record.state.isHeld { return "沉淀中…" }
        return last.text
    }

    // MARK: Sending

    func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let record = CalmMessage(text: trimmed, createdAt: app.now)
        records[record.id] = record
        messages.append(Message(id: record.id, user: Self.me, status: .sending, createdAt: record.createdAt, text: record.text))
        score(record.text) { [weak self] score in
            self?.send(record.id, .scored(score))
        }
    }

    /// Applies one reducer event and runs its side effects.
    func send(_ id: String, _ event: SettleEvent) {
        guard let old = records[id] else { return }
        let new = reduce(old, event, now: app.now, policy: app.policy)
        guard new != old else { return }
        records[id] = new
        updateDisplay(new)
        runEffects(from: old, to: new)
    }

    func submitRewrite(_ id: String, text: String) {
        send(id, .submitRewrite(text))
        score(text) { [weak self] score in
            guard let self else { return }
            self.send(id, .rescored(score))
            switch self.records[id]?.state {
            case .delivered?: self.showBanner("改写后平静多了，已送达")
            case .settling?, .ready?: self.showBanner("还是有点冲，继续沉淀")
            default: break
            }
        }
    }

    func tick() {
        for (id, record) in records where record.state == .settling {
            send(id, .tick)
        }
    }

    /// Tapping a held bubble.
    func tap(_ id: String) {
        guard let record = records[id] else { return }
        switch record.state {
        case .settling:
            route = .actions(id)
        case .ready:
            send(id, .openConfirm)
            route = .confirm(id)
        default:
            break
        }
    }

    func rescheduleNotifications() {
        for record in records.values where record.state.isHeld && record.state != .dissolving {
            app.notifications.schedule(for: record, peerName: peer.name, clock: app.clock, policy: app.policy)
        }
    }

    // MARK: Effects

    private func runEffects(from old: CalmMessage, to new: CalmMessage) {
        switch new.state {
        case .delivered:
            app.notifications.cancel(id: new.id)
            Task { await transport.send(WireMessage(id: new.id, text: new.text, sentAt: new.deliveredAt ?? app.now)) }
        case .settling where old.state == .scoring:
            app.notifications.schedule(for: new, peerName: peer.name, clock: app.clock, policy: app.policy)
        case .dissolving:
            app.notifications.cancel(id: new.id)
            Task { [weak self] in
                try? await Task.sleep(for: DissolveBubble.duration)
                self?.send(new.id, .dissolveFinished)
            }
        case .dissolved:
            records[new.id] = nil
            messages.removeAll { $0.id == new.id }
        default:
            break
        }
    }

    private func updateDisplay(_ record: CalmMessage) {
        guard let index = messages.firstIndex(where: { $0.id == record.id }) else { return }
        var message = Message(
            id: record.id,
            user: Self.me,
            status: record.state == .delivered ? .sent : .sending,
            createdAt: record.createdAt,
            text: record.text
        )
        // Forces exyte to redraw the row even when only the settle state changed.
        message.triggerRedraw = UUID()
        messages[index] = message
    }

    private func listen() {
        let incoming = transport.incoming
        Task { [weak self] in
            for await wire in incoming {
                guard let self else { return }
                self.messages.append(Message(id: wire.id, user: self.peer, createdAt: wire.sentAt, text: wire.text))
            }
        }
    }

    private func score(_ text: String, then: @escaping (Double) -> Void) {
        let scorer = app.scorer
        Task {
            // Off the main actor: a Core ML prediction takes tens of milliseconds.
            let score = await Task.detached { scorer.score(text) }.value
            then(score)
        }
    }

    private func showBanner(_ text: String) {
        banner = text
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            if self?.banner == text { self?.banner = nil }
        }
    }
}
