import Foundation

/// One highlight on the 「三思」 page: a short title and one sentence, written the
/// way Apple's Health and Screen Time summaries are: second person, plain,
/// specific numbers, encouraging without exclamation marks.
public struct ThinkInsight: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case calmStreak, letGo, rewrite, tookTime, tryWaiting
    }

    public var kind: Kind
    public var title: String
    public var detail: String
}

/// The week in words: a headline, a sentence of evidence, a closing line, and up to four highlights.
public struct ThinkReview: Equatable, Sendable {
    public var headline: String
    public var detail: String
    public var closing: String
    public var insights: [ThinkInsight]
}

extension ThinkStats {
    public func review(endingAt now: Date) -> ThinkReview {
        let (this, last) = weeks(endingAt: now)
        return ThinkReview(
            headline: Self.headline(this: this, last: last),
            detail: Self.detail(this: this, last: last),
            closing: Self.closing(this),
            insights: insights(this: this, last: last, now: now)
        )
    }

    /// Days in a row, ending today, on which nothing was frozen and something was written.
    /// Quiet days without messages neither break nor extend the streak.
    public func calmStreak(endingAt now: Date) -> Int {
        var streak = 0
        for day in daily(days: 30, endingAt: now).reversed() {
            if day.summary.count(.held) > 0 { break }
            if day.summary.written > 0 { streak += 1 }
        }
        return streak
    }

    private static func percent(_ rate: Double) -> Int { Int((rate * 100).rounded()) }

    static func headline(this: Summary, last: Summary) -> String {
        guard let rate = this.holdRate else { return "这周很安静。" }
        if this.count(.held) == 0 { return "这周，你说的每句话都很平静。" }
        guard let lastRate = last.holdRate else { return "你已经开始先想一想，再发出去。" }
        let change = percent(rate) - percent(lastRate)
        if change <= -3 { return "这周，你更常先停下来。" }
        if change >= 3 { return "这周，情绪起伏多了一些。" }
        return "你保持住了自己的节奏。"
    }

    static func detail(this: Summary, last: Summary) -> String {
        guard let rate = this.holdRate else { return "你发出的每一条消息，都会在这里留下记录。" }
        let now = percent(rate)
        guard let lastRate = last.holdRate else {
            return "这周写了 \(this.written) 条消息，其中 \(now)% 先被冻住了。"
        }
        let before = percent(lastRate)
        if now < before { return "被冻住的消息占 \(now)%，上周是 \(before)%。冲动的时刻在变少。" }
        if now > before { return "被冻住的消息占 \(now)%，上周是 \(before)%。没关系，每一次停下来，都是在给自己留余地。" }
        return "被冻住的消息占 \(now)%，和上周一样。"
    }

    static func closing(_ this: Summary) -> String {
        guard this.holdRate != nil else { return "下次想发消息时，ThinkThrice 会陪你多想一步。" }
        switch this.score {
        case 80...: return "继续保持。"
        case 60..<80: return "你正在养成一个好习惯。"
        default: return "每一次停下来，都算数。"
        }
    }

    func insights(this: Summary, last: Summary, now: Date) -> [ThinkInsight] {
        var out: [ThinkInsight] = []
        let streak = calmStreak(endingAt: now)
        if streak >= 2 {
            out.append(ThinkInsight(kind: .calmStreak, title: "连续 \(streak) 天心平气和", detail: "这几天发出的消息，没有一条需要被冻住。"))
        }
        let letGo = this.count(.letGo)
        if letGo > 0 {
            let more = letGo - last.count(.letGo)
            let lead = more > 0 ? "比上周多 \(more) 条。" : ""
            out.append(ThinkInsight(kind: .letGo, title: "你放下了 \(letGo) 条消息", detail: lead + "不是每句话，都需要被发出去。"))
        }
        let rewrote = this.count(.rewroteCalm)
        if rewrote > 0 {
            out.append(ThinkInsight(kind: .rewrite, title: "\(rewrote) 条消息改写后送达", detail: "换一种说法，意思还在，语气更温和了。"))
        }
        let waited = this.count(.waitedSent), cooled = this.count(.cooled)
        if waited + cooled > 0 {
            let parts = [waited > 0 ? "\(waited) 条消息等冷静期过了才发出" : nil, cooled > 0 ? "\(cooled) 次主动按下了暂停" : nil].compactMap { $0 }
            out.append(ThinkInsight(kind: .tookTime, title: "你给了自己时间", detail: parts.joined(separator: "，") + "。"))
        }
        let ritual = this.count(.ritualSent)
        if ritual > 0, ritual >= letGo + rewrote {
            out.append(ThinkInsight(kind: .tryWaiting, title: "下次，试试再等一等", detail: "这周有 \(ritual) 条消息走完仪式后仍然发出。睡一觉再看，常常会有不同的想法。"))
        }
        return Array(out.prefix(4))
    }
}
