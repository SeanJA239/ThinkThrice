import CalmCore
import Foundation
import Observation

/// The log behind the 「三思」 page: one `ThinkEvent` per step of the settle flow,
/// saved as JSON next to the conversations.
///
/// On first launch it is seeded with two weeks of example history so the page
/// has something to show in a demo; `seededExample` marks that, and the page says so.
@Observable
final class StatsStore {
    private(set) var events: [ThinkEvent] = []
    /// Example events are all dated before this; nil once they are cleared.
    private(set) var exampleBefore: Date?
    var seededExample: Bool { exampleBefore != nil }

    private struct File: Codable {
        var events: [ThinkEvent]
        var exampleBefore: Date?
    }

    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Conversations/stats.json")
    }

    init(now: Date) {
        if let data = try? Data(contentsOf: Self.url), let file = try? JSONDecoder().decode(File.self, from: data) {
            events = file.events
            exampleBefore = file.exampleBefore
        } else {
            reset(now: now)
        }
    }

    func record(_ kind: ThinkEvent.Kind, at date: Date) {
        events.append(ThinkEvent(kind, at: date))
        save()
    }

    /// Drops the example history and keeps only what really happened.
    func clearExample() {
        guard let exampleBefore else { return }
        events.removeAll { $0.date < exampleBefore }
        self.exampleBefore = nil
        save()
    }

    func reset(now: Date) {
        let today = Calendar.current.startOfDay(for: now)
        events = Self.example(before: today)
        exampleBefore = today
        save()
    }

    func stats(calendar: Calendar) -> ThinkStats {
        ThinkStats(events: events, calendar: calendar)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(File(events: events, exampleBefore: exampleBefore)).write(to: Self.url, options: .atomic)
        } catch {
            // Best effort, like the conversation archive.
            print("Could not save stats: \(error)")
        }
    }

    /// Two weeks that improve: holds fall from about half of all messages to a
    /// fifth, and more of them end in a rewrite or letting go.
    private static func example(before today: Date) -> [ThinkEvent] {
        let calendar = Calendar.current
        var events: [ThinkEvent] = []
        for back in 1...14 {
            let day = calendar.date(byAdding: .day, value: -back, to: today)!
            let improvement = Double(14 - back) / 13
            let written = 6 + (back * 7) % 5
            let held = max(1, Int((Double(written) * (0.5 - 0.3 * improvement)).rounded()))
            var kinds = Array(repeating: ThinkEvent.Kind.sentDirectly, count: written - held)
            kinds += Array(repeating: .held, count: held)
            for i in 0..<held {
                let r = Double((i * 37 + back * 11) % 100) / 100
                if r < 0.45 * improvement + 0.1 { kinds.append(.letGo) }
                else if r < 0.75 * improvement + 0.2 { kinds.append(.rewroteCalm) }
                else if r < 0.9 { kinds.append(.waitedSent) }
                else { kinds.append(.ritualSent) }
            }
            if back % 5 == 0 { kinds.append(.cooled) }
            for (i, kind) in kinds.enumerated() {
                events.append(ThinkEvent(kind, at: day.addingTimeInterval(9 * 3600 + Double(i) * 1700)))
            }
        }
        return events.sorted { $0.date < $1.date }
    }
}
