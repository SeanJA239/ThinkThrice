import Foundation

private func t(_ english: Bool, _ zh: String, _ en: String) -> String { english ? en : zh }
private func plural(_ n: Int, _ word: String) -> String { n == 1 ? word : word + "s" }

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
    public func review(endingAt now: Date, english: Bool = false) -> ThinkReview {
        let (this, last) = weeks(endingAt: now)
        return ThinkReview(
            headline: Self.headline(this: this, last: last, english: english),
            detail: Self.detail(this: this, last: last, english: english),
            closing: Self.closing(this, english: english),
            insights: insights(this: this, last: last, now: now, english: english)
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

    static func headline(this: Summary, last: Summary, english: Bool = false) -> String {
        guard let rate = this.holdRate else { return t(english, "这周很安静。", "A quiet week.") }
        if this.count(.held) == 0 { return t(english, "这周，你说的每句话都很平静。", "This week, everything you said was calm.") }
        guard let lastRate = last.holdRate else { return t(english, "你已经开始先想一想，再发出去。", "You've started to think before you send.") }
        let change = percent(rate) - percent(lastRate)
        if change <= -3 { return t(english, "这周，你更常先停下来。", "This week, you paused more often.") }
        if change >= 3 { return t(english, "这周，情绪起伏多了一些。", "This week had a few more ups and downs.") }
        return t(english, "你保持住了自己的节奏。", "You kept your own pace.")
    }

    static func detail(this: Summary, last: Summary, english: Bool = false) -> String {
        guard let rate = this.holdRate else { return t(english, "你发出的每一条消息，都会在这里留下记录。", "Every message you send shows up here.") }
        let now = percent(rate)
        guard let lastRate = last.holdRate else {
            return t(english, "这周写了 \(this.written) 条消息，其中 \(now)% 先被冻住了。", "You wrote \(this.written) \(plural(this.written, "message")) this week, and \(now)% were frozen first.")
        }
        let before = percent(lastRate)
        if now < before { return t(english, "被冻住的消息占 \(now)%，上周是 \(before)%。冲动的时刻在变少。", "\(now)% of messages were frozen, down from \(before)% last week. Impulsive moments are getting rarer.") }
        if now > before { return t(english, "被冻住的消息占 \(now)%，上周是 \(before)%。没关系，每一次停下来，都是在给自己留余地。", "\(now)% of messages were frozen, up from \(before)% last week. That's all right: every pause gives you room.") }
        return t(english, "被冻住的消息占 \(now)%，和上周一样。", "\(now)% of messages were frozen, the same as last week.")
    }

    static func closing(_ this: Summary, english: Bool = false) -> String {
        guard this.holdRate != nil else { return t(english, "下次想发消息时，ThinkThrice 会陪你多想一步。", "Next time you write, ThinkThrice will help you think one step further.") }
        switch this.score {
        case 80...: return t(english, "继续保持。", "Keep it up.")
        case 60..<80: return t(english, "你正在养成一个好习惯。", "You're building a good habit.")
        default: return t(english, "每一次停下来，都算数。", "Every pause counts.")
        }
    }

    func insights(this: Summary, last: Summary, now: Date, english: Bool = false) -> [ThinkInsight] {
        var out: [ThinkInsight] = []
        let streak = calmStreak(endingAt: now)
        if streak >= 2 {
            out.append(ThinkInsight(kind: .calmStreak, title: t(english, "连续 \(streak) 天心平气和", "\(streak) calm days in a row"), detail: t(english, "这几天发出的消息，没有一条需要被冻住。", "Nothing you sent these days needed to be frozen.")))
        }
        let letGo = this.count(.letGo)
        if letGo > 0 {
            let more = letGo - last.count(.letGo)
            let lead = more > 0 ? t(english, "比上周多 \(more) 条。", "\(more) more than last week. ") : ""
            out.append(ThinkInsight(kind: .letGo, title: t(english, "你放下了 \(letGo) 条消息", "You let go of \(letGo) \(plural(letGo, "message"))"), detail: lead + t(english, "不是每句话，都需要被发出去。", "Not every sentence needs to be sent.")))
        }
        let rewrote = this.count(.rewroteCalm)
        if rewrote > 0 {
            out.append(ThinkInsight(kind: .rewrite, title: t(english, "\(rewrote) 条消息改写后送达", "\(rewrote) \(plural(rewrote, "message")) delivered after a rewrite"), detail: t(english, "换一种说法，意思还在，语气更温和了。", "Same meaning, gentler words.")))
        }
        let waited = this.count(.waitedSent), cooled = this.count(.cooled)
        if waited + cooled > 0 {
            let parts = [waited > 0 ? t(english, "\(waited) 条消息等冷静期过了才发出", "\(waited) \(plural(waited, "message")) sent after cooling down") : nil, cooled > 0 ? t(english, "\(cooled) 次主动按下了暂停", "\(cooled) \(plural(cooled, "pause")) you chose to take") : nil].compactMap { $0 }
            out.append(ThinkInsight(kind: .tookTime, title: t(english, "你给了自己时间", "You gave yourself time"), detail: parts.joined(separator: t(english, "，", ", ")) + t(english, "。", ".")))
        }
        let ritual = this.count(.ritualSent)
        if ritual > 0, ritual >= letGo + rewrote {
            out.append(ThinkInsight(kind: .tryWaiting, title: t(english, "下次，试试再等一等", "Next time, try waiting a little longer"), detail: t(english, "这周有 \(ritual) 条消息走完仪式后仍然发出。睡一觉再看，常常会有不同的想法。", "\(ritual) \(plural(ritual, "message")) \(ritual == 1 ? "was" : "were") still sent after the ritual this week. Things often look different after a night's sleep.")))
        }
        return Array(out.prefix(4))
    }
}
