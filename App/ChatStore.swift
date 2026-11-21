import CalmCore
import ExyteChat
import Foundation
import Observation
import SwiftUI

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

    /// What this side shows the other: chosen in the contact sheet. 冷静 is also
    /// set automatically during a cooling pause.
    enum MyStatus: String, Codable, CaseIterable, Identifiable {
        case auto, calm, busy, offline
        var id: String { rawValue }
        var label: String {
            switch self {
            case .auto: "在线"
            case .calm: "冷静中"
            case .busy: "忙碌"
            case .offline: "离线"
            }
        }
        /// The status light: green when online, like the dot on the chat header.
        var color: Color {
            switch self {
            case .auto: .green
            case .calm: Theme.ice
            case .busy: .orange
            case .offline: .gray
            }
        }
        var symbol: String {
            switch self {
            case .auto: "circle.fill"
            case .calm: "snowflake"
            case .busy: "minus.circle.fill"
            case .offline: "moon.fill"
            }
        }
    }
    var myStatus: MyStatus = .auto { didSet { save() } }
    var note = "" { didSet { save() } }
    var muted = false { didSet { save() } }
    var pinned = false { didSet { save() } }

    /// The name shown everywhere: the note if one is set.
    var displayName: String { note.isEmpty ? peer.name : note }

    /// The cooling pause: until then, my new messages are held and the other
    /// side's replies wait, so both sides stop for a while.
    static let coolingDuration: TimeInterval = 15 * 60
    private(set) var coolUntil: Date?
    private var heldIncoming: [WireMessage] = []

    var isCooling: Bool { coolUntil.map { app.now < $0 } ?? false }

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
            coolUntil = archive.coolUntil
            heldIncoming = archive.heldIncoming ?? []
            myStatus = archive.myStatus ?? .auto
            note = archive.note ?? ""
            muted = archive.muted ?? false
            pinned = archive.pinned ?? false
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
        if let record = records[last.id], record.state.isHeld { return "冷静中…" }
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
        if isCooling, let coolUntil {
            send(record.id, .hold(until: coolUntil))
            return
        }
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
            case .settling?, .ready?: self.showBanner("还是有点冲，继续冷静")
            default: break
            }
        }
    }

    func tick() {
        for (id, record) in records where record.state == .settling {
            send(id, .tick)
        }
        if coolUntil != nil, !isCooling { endCooling() }
    }

    // MARK: Cooling

    func startCooling() {
        let until = app.now.addingTimeInterval(Self.coolingDuration)
        coolUntil = until
        myStatus = .calm
        app.stats.record(.cooled, at: app.now)
        Haptics.freeze()
        showBanner("双方冷静 15 分钟，\(until.formatted(date: .omitted, time: .shortened)) 再继续")
        save()
    }

    /// Ends the pause, early or on time: held replies arrive, and messages I
    /// wrote meanwhile are ready to confirm.
    func endCooling() {
        coolUntil = nil
        if myStatus == .calm { myStatus = .auto }
        for wire in heldIncoming {
            messages.append(Message(id: wire.id, user: peer, createdAt: wire.sentAt, text: wire.text))
        }
        heldIncoming = []
        for (id, record) in records where record.state == .settling && record.lastScore == nil {
            send(id, .tick)
        }
        showBanner("冷静结束")
        save()
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
        recordStats(from: old, to: new)
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

    /// Feeds the 「三思」 page. A message held by a cooling pause (no score) is not
    /// counted as impulsive.
    private func recordStats(from old: CalmMessage, to new: CalmMessage) {
        let kind: ThinkEvent.Kind?
        switch (old.state, new.state) {
        case (.scoring, .delivered): kind = .sentDirectly
        case (.ritual, .delivered): kind = .ritualSent
        case (.confirming, .delivered): kind = .waitedSent
        case (.rescoring, .delivered): kind = .rewroteCalm
        case (.scoring, .settling), (.scoring, .ready): kind = new.lastScore == nil ? nil : .held
        case (.rescoring, .settling), (.rescoring, .ready): kind = .rewroteStill
        case (_, .dissolving): kind = .letGo
        default: kind = nil
        }
        if let kind { app.stats.record(kind, at: app.now) }
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
                if self.isCooling {
                    self.heldIncoming.append(wire)
                } else {
                    self.messages.append(Message(id: wire.id, user: self.peer, createdAt: wire.sentAt, text: wire.text))
                }
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
        ConversationArchive(
            entries: entries, repliesUsed: repliesUsed, coolUntil: coolUntil, heldIncoming: heldIncoming,
            myStatus: myStatus, note: note, muted: muted, pinned: pinned
        ).save(id: id)
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

    /// Judges `text` for this conversation's recipient, as late night when the
    /// demo clock says night, and hands back the verdict's 0…1 impulse.
    private func score(_ text: String, then: @escaping (Double) -> Void) {
        let judge = app.judge
        let recipient = conversation.recipient
        let lateNight = app.policy.isNight(app.now)
        Task {
            // Off the main actor: a Core ML prediction takes tens of milliseconds.
            let verdict = await Task.detached { judge.judge(text, to: recipient, lateNight: lateNight) }.value
            then(verdict.impulse)
        }
    }

    /// Why a held message was held, from the rules alone (no model call): the
    /// matched words and their list, as they were at the time it was written.
    func holdReason(for record: CalmMessage) -> Verdict {
        ThinkThriceRules.judgeMessage(record.text, modelProb: 0, to: conversation.recipient,
                                      lateNight: app.policy.isNight(record.createdAt),
                                      contextFactor: conversation.recipient.contextFactor)
    }

    private func showBanner(_ text: String) {
        banner = text
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            if self?.banner == text { self?.banner = nil }
        }
    }
}
