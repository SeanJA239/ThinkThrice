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
    /// True while a reply from the other side is on its way; the header shows 「正在输入…」.
    private(set) var peerIsTyping = false
    private var repliesInFlight = 0

    /// Whether the other side can be reached. Scripted peers are always online;
    /// a two-phone conversation follows its connection.
    enum Presence { case online, searching, disconnected }
    private(set) var presence: Presence = .online

    private unowned let app: AppModel
    private let transport: any MessageTransport
    /// How many scripted replies have arrived, saved so a relaunch continues the script.
    private var repliesUsed = 0

    var id: String { conversation.id }

    /// With a `p2pRole`, the other side is a second phone instead of the script.
    init(conversation: Content.Conversation, app: AppModel, p2pRole: P2PTransport.Role? = nil) {
        self.conversation = conversation
        self.app = app
        peer = User(id: conversation.id, name: conversation.name, avatarURL: nil, isCurrentUser: false)
        let archive = ConversationArchive.load(id: conversation.id)
        let repliesUsed = archive?.repliesUsed ?? 0
        self.repliesUsed = repliesUsed
        if let p2pRole {
            let p2p = P2PTransport(role: p2pRole)
            transport = p2p
            presence = .searching
            followStatus(of: p2p)
        } else {
            transport = ScriptedTransport(replies: Array(conversation.replies.dropFirst(repliesUsed)), clock: app.clock)
        }
        if let archive {
            restore(archive)
        } else {
            let start = app.now.addingTimeInterval(-Double(conversation.seed.count) * 60)
            messages = conversation.seed.enumerated().map { index, text in
                Message(id: UUID().uuidString, user: peer, createdAt: start.addingTimeInterval(Double(index) * 60), text: text)
            }
            save()
        }
        listen()
    }

    /// Stops a two-phone connection. Call before dropping the store.
    func stop() {
        (transport as? P2PTransport)?.stop()
    }

    /// The newest delivered outgoing message, the only one that shows 「已送达」.
    var lastDeliveredID: String? {
        messages.last { records[$0.id]?.state == .delivered }?.id
    }

    /// Where a row sits in its run of consecutive messages from one sender, iMessage
    /// style: the first gets extra space above, the last gets the tail. Held messages
    /// stand alone, so a frozen bubble never joins a group.
    func groupPosition(of id: String) -> (isFirst: Bool, isLast: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return (true, true) }
        func isHeld(_ message: Message) -> Bool {
            records[message.id].map { $0.state != .delivered } ?? false
        }
        func joins(_ a: Int, _ b: Int) -> Bool {
            messages[a].user.id == messages[b].user.id && !isHeld(messages[a]) && !isHeld(messages[b])
        }
        let isFirst = index == 0 || !joins(index - 1, index)
        let isLast = index == messages.count - 1 || !joins(index, index + 1)
        return (isFirst, isLast)
    }

    /// Messages still held on this phone, shown as a badge in the conversation list.
    var heldCount: Int {
        records.values.filter { $0.state.isHeld && $0.state != .dissolving }.count
    }

    /// When the newest row happened: delivery time for my delivered messages.
    var lastActivity: Date? {
        guard let last = messages.last else { return nil }
        guard let record = records[last.id] else { return last.createdAt }
        return record.deliveredAt ?? record.createdAt
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
        messages.append(Self.display(record))
        save()
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
        save()
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
            if old.state == .scoring { Haptics.sent() } else { Haptics.delivered() }
            let wire = WireMessage(id: new.id, text: new.text, sentAt: new.deliveredAt ?? app.now)
            Task { [weak self] in
                guard let self else { return }
                // ScriptedTransport.send returns after its reply is out, so this spans the "typing" delay.
                self.repliesInFlight += 1
                self.peerIsTyping = true
                await self.transport.send(wire)
                self.repliesInFlight -= 1
                self.peerIsTyping = self.repliesInFlight > 0
            }
        case .settling where old.state == .scoring:
            Haptics.freeze()
            app.notifications.schedule(for: new, peerName: peer.name, clock: app.clock, policy: app.policy)
        case .settling where old.state == .rescoring, .ready where old.state == .rescoring:
            Haptics.freeze()
        case .dissolving:
            Haptics.dissolve()
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

    private static func display(_ record: CalmMessage) -> Message {
        Message(
            id: record.id,
            user: me,
            status: record.state == .delivered ? .sent : .sending,
            createdAt: record.createdAt,
            text: record.text
        )
    }

    private func updateDisplay(_ record: CalmMessage) {
        guard let index = messages.firstIndex(where: { $0.id == record.id }) else { return }
        var message = Self.display(record)
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
                self.repliesUsed += 1
                self.save()
            }
        }
    }

    private func followStatus(of p2p: P2PTransport) {
        let updates = p2p.statusUpdates
        Task { [weak self] in
            for await status in updates {
                switch status {
                case .searching: self?.presence = .searching
                case .connected: self?.presence = .online
                case .disconnected: self?.presence = .disconnected
                }
            }
        }
    }

    // MARK: Persistence

    private func save() {
        let entries: [ConversationArchive.Entry] = messages.map { message in
            if let record = records[message.id] { return .mine(record) }
            return .peer(WireMessage(id: message.id, text: message.text, sentAt: message.createdAt))
        }
        ConversationArchive(entries: entries, repliesUsed: repliesUsed).save(id: id)
    }

    /// Rebuilds the conversation from its archive. Sheets didn't survive the
    /// relaunch, so each record goes through `.relaunched`; messages that were
    /// still being scored are scored again.
    private func restore(_ archive: ConversationArchive) {
        for entry in archive.entries {
            switch entry {
            case .peer(let wire):
                messages.append(Message(id: wire.id, user: peer, createdAt: wire.sentAt, text: wire.text))
            case .mine(let saved):
                let record = reduce(saved, .relaunched, now: app.now, policy: app.policy)
                guard record.state != .dissolved else { continue }
                records[record.id] = record
                messages.append(Self.display(record))
                if record.state == .scoring {
                    score(record.text) { [weak self] score in self?.send(record.id, .scored(score)) }
                }
            }
        }
        save()
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
