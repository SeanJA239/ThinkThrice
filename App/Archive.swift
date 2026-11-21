import CalmCore
import Foundation

/// What is saved for one conversation, so held messages and their countdowns
/// survive killing and reopening the app.
///
/// One JSON file per conversation in Application Support. `CalmMessage` is
/// already `Codable`, so the archive is a plain snapshot instead of a SwiftData
/// model: there is nothing to query, and the state machine stays the only thing
/// that changes a record.
struct ConversationArchive: Codable {
    enum Entry: Codable {
        /// A message from the other side.
        case peer(WireMessage)
        /// One of mine, in whatever settle state it was in.
        case mine(CalmMessage)
    }

    var entries: [Entry]
    /// How many scripted replies the other side has already sent.
    var repliesUsed: Int

    private static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Conversations", directoryHint: .isDirectory)
    }

    private static func url(for id: String) -> URL {
        directory.appending(path: "\(id).json")
    }

    static func load(id: String) -> ConversationArchive? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        // A file from an older build that no longer decodes starts the conversation over.
        return try? JSONDecoder().decode(ConversationArchive.self, from: data)
    }

    func save(id: String) {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(self).write(to: Self.url(for: id), options: .atomic)
        } catch {
            // Saving is best effort: the demo keeps running from memory.
            print("Could not save conversation \(id): \(error)")
        }
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// Demo settings that should also survive a relaunch: the demo clock's offset
/// and the thresholds tuned on site.
enum DemoSettings {
    private static let defaults = UserDefaults.standard

    static var clockOffset: TimeInterval {
        get { defaults.double(forKey: "clockOffset") }
        set { defaults.set(newValue, forKey: "clockOffset") }
    }

    static var thresholds: (night: Double, day: Double)? {
        get {
            guard defaults.object(forKey: "nightThreshold") != nil else { return nil }
            return (defaults.double(forKey: "nightThreshold"), defaults.double(forKey: "dayThreshold"))
        }
        set {
            if let newValue {
                defaults.set(newValue.night, forKey: "nightThreshold")
                defaults.set(newValue.day, forKey: "dayThreshold")
            } else {
                defaults.removeObject(forKey: "nightThreshold")
                defaults.removeObject(forKey: "dayThreshold")
            }
        }
    }

    static var p2pRole: P2PTransport.Role? {
        get { defaults.string(forKey: "p2pRole").flatMap(P2PTransport.Role.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "p2pRole") }
    }

    static func reset() {
        for key in ["clockOffset", "nightThreshold", "dayThreshold"] {
            defaults.removeObject(forKey: key)
        }
    }
}
