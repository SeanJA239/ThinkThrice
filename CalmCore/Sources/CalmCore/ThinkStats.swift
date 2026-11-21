import Foundation

/// One thing that happened in the settle flow, kept for the progress page.
public struct ThinkEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// Scored calm and delivered straight away.
        case sentDirectly
        /// Scored impulsive and held.
        case held
        /// Delivered after the high-cost ritual.
        case ritualSent
        /// Delivered after waiting until it was ready.
        case waitedSent
        /// Rewritten and calm enough to deliver.
        case rewroteCalm
        /// Rewritten but still impulsive.
        case rewroteStill
        /// Let go.
        case letGo
        /// Started a 15-minute cooling pause in a conversation.
        case cooled
    }

    public var kind: Kind
    public var date: Date

    public init(_ kind: Kind, at date: Date) {
        self.kind = kind
        self.date = date
    }
}

/// Progress in thinking twice, from a log of events.
///
/// Fewer holds, and more rewrites, let-gos, waits and cooling pauses are good
/// signs; sending through the ritual anyway is the least reflective way out.
public struct ThinkStats: Equatable, Sendable {
    public struct Summary: Equatable, Sendable {
        public var counts: [ThinkEvent.Kind: Int]

        public func count(_ kind: ThinkEvent.Kind) -> Int { counts[kind, default: 0] }

        /// Messages written in the period.
        public var written: Int { count(.sentDirectly) + count(.held) }

        /// Share of written messages that were held, 0…1; nil with nothing written.
        public var holdRate: Double? {
            written == 0 ? nil : Double(count(.held)) / Double(written)
        }

        /// How the held messages ended, weighted: letting go and a calm rewrite
        /// count fully, waiting or a still-impulsive rewrite half, the ritual not at all.
        public var reflectiveExits: Double {
            Double(count(.letGo) + count(.rewroteCalm)) + 0.5 * Double(count(.waitedSent) + count(.rewroteStill))
        }

        /// 0…100: half for holding less, half for how reflectively held messages
        /// were handled. Cooling pauses add 5 points each, up to 10.
        public var score: Int {
            guard let holdRate else { return 0 }
            let exits = count(.held) == 0 ? 1 : min(1, reflectiveExits / Double(count(.held)))
            let base = 50 * (1 - holdRate) + 50 * exits
            return Int(min(100, base + Double(min(2, count(.cooled)) * 5)).rounded())
        }
    }

    public var events: [ThinkEvent]
    public var calendar: Calendar

    public init(events: [ThinkEvent], calendar: Calendar = .current) {
        self.events = events
        self.calendar = calendar
    }

    public func summary(from start: Date, to end: Date) -> Summary {
        var counts: [ThinkEvent.Kind: Int] = [:]
        for event in events where event.date >= start && event.date < end {
            counts[event.kind, default: 0] += 1
        }
        return Summary(counts: counts)
    }

    /// The 7 days ending with `now`'s day, and the 7 before them.
    public func weeks(endingAt now: Date) -> (this: Summary, last: Summary) {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: tomorrow)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: tomorrow)!
        return (summary(from: weekAgo, to: tomorrow), summary(from: twoWeeksAgo, to: weekAgo))
    }

    /// One summary per day for the last `days` days, oldest first.
    public func daily(days: Int, endingAt now: Date) -> [(day: Date, summary: Summary)] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().map { back in
            let day = calendar.date(byAdding: .day, value: -back, to: today)!
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            return (day, summary(from: day, to: next))
        }
    }
}
