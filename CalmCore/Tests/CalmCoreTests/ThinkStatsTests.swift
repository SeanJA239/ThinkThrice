import Foundation
import Testing
@testable import CalmCore

@Suite struct HoldUntilTests {
    @Test func coolingHoldsUntilTheGivenTimeWithoutAScore() {
        let m = reduce(CalmMessage(text: "好的", createdAt: at(21, 14)), .hold(until: at(21, 14, 15)), now: at(21, 14), policy: policy)
        #expect(m.state == .settling)
        #expect(m.settleUntil == at(21, 14, 15))
        #expect(m.lastScore == nil)
        #expect(reduce(m, .tick, now: at(21, 14, 15), policy: policy).state == .ready)
    }

    @Test func holdOnlyAppliesWhileScoring() {
        let delivered = sent("a", score: 0.1, at: at(21, 14))
        #expect(reduce(delivered, .hold(until: at(21, 15)), now: at(21, 14), policy: policy) == delivered)
    }
}

@Suite struct ThinkStatsTests {
    func stats(_ kinds: [ThinkEvent.Kind], on day: Int) -> [ThinkEvent] {
        kinds.map { ThinkEvent($0, at: at(day, 12)) }
    }

    @Test func holdingLessScoresHigher() {
        let often = ThinkStats.Summary(counts: [.sentDirectly: 2, .held: 2, .letGo: 2])
        let rarely = ThinkStats.Summary(counts: [.sentDirectly: 3, .held: 1, .letGo: 1])
        #expect(rarely.score > often.score)
    }

    @Test func reflectiveExitsScoreHigherThanTheRitual() {
        let ritual = ThinkStats.Summary(counts: [.sentDirectly: 2, .held: 2, .ritualSent: 2])
        let letGo = ThinkStats.Summary(counts: [.sentDirectly: 2, .held: 2, .letGo: 2])
        let mixed = ThinkStats.Summary(counts: [.sentDirectly: 2, .held: 2, .waitedSent: 1, .rewroteCalm: 1])
        #expect(ritual.score == 25)
        #expect(letGo.score == 75)
        #expect(mixed.score == 63)
    }

    @Test func nothingWrittenScoresZeroAndNoHoldsScoresFull() {
        #expect(ThinkStats.Summary(counts: [:]).score == 0)
        #expect(ThinkStats.Summary(counts: [:]).holdRate == nil)
        #expect(ThinkStats.Summary(counts: [.sentDirectly: 5]).score == 100)
    }

    @Test func coolingAddsAtMostTenPoints() {
        let base = ThinkStats.Summary(counts: [.sentDirectly: 1, .held: 1, .ritualSent: 1])
        #expect(base.score == 25)
        #expect(ThinkStats.Summary(counts: [.sentDirectly: 1, .held: 1, .ritualSent: 1, .cooled: 5]).score == 35)
    }

    @Test func weeksSplitAtDayBoundaries() {
        // `now` is 21 Nov 14:00; this week is 15–21 Nov, last week 8–14 Nov.
        let events = stats([.held], on: 21) + stats([.held, .held], on: 15) + stats([.held], on: 14) + stats([.held], on: 8) + stats([.held], on: 7)
        let weeks = ThinkStats(events: events, calendar: shanghai).weeks(endingAt: at(21, 14))
        #expect(weeks.this.count(.held) == 3)
        #expect(weeks.last.count(.held) == 2)
    }

    @Test func dailyIsOldestFirstAndCountsEachDay() {
        let events = stats([.held, .letGo], on: 21) + stats([.sentDirectly], on: 19)
        let days = ThinkStats(events: events, calendar: shanghai).daily(days: 3, endingAt: at(21, 9))
        #expect(days.map { shanghai.component(.day, from: $0.day) } == [19, 20, 21])
        #expect(days.map { $0.summary.written } == [1, 0, 1])
        #expect(days[2].summary.count(.letGo) == 1)
    }
}

@Suite struct ThinkReviewTests {
    func events(_ kinds: [ThinkEvent.Kind], on day: Int) -> [ThinkEvent] {
        kinds.map { ThinkEvent($0, at: at(day, 12)) }
    }

    func review(_ events: [ThinkEvent]) -> ThinkReview {
        ThinkStats(events: events, calendar: shanghai).review(endingAt: at(21, 20))
    }

    @Test func headlineFollowsTheHoldRate() {
        // Last week (8–14 Nov) half was held; this week a quarter.
        let better = events([.sentDirectly, .held], on: 10) + events([.sentDirectly, .sentDirectly, .sentDirectly, .held], on: 20)
        #expect(review(better).headline == "这周，你更常先停下来。")
        #expect(review(better).detail.hasPrefix("被冻住的消息占 25%，上周是 50%。"))
        let worse = events([.sentDirectly, .sentDirectly, .sentDirectly, .held], on: 10) + events([.sentDirectly, .held], on: 20)
        #expect(review(worse).headline == "这周，情绪起伏多了一些。")
        #expect(review([]).headline == "这周很安静。")
        #expect(review(events([.sentDirectly], on: 20)).headline == "这周，你说的每句话都很平静。")
    }

    @Test func calmStreakSkipsQuietDaysAndStopsAtAHold() {
        let log = events([.held], on: 17) + events([.sentDirectly], on: 18) + events([.sentDirectly], on: 20) + events([.sentDirectly], on: 21)
        #expect(ThinkStats(events: log, calendar: shanghai).calmStreak(endingAt: at(21, 20)) == 3)
        #expect(review(log).insights.first?.title == "连续 3 天心平气和")
    }

    @Test func waitingTipOnlyWhenTheRitualWins() {
        let ritualHeavy = events([.held, .held, .ritualSent, .ritualSent, .letGo], on: 20)
        #expect(review(ritualHeavy).insights.contains { $0.kind == .tryWaiting })
        let reflective = events([.held, .held, .ritualSent, .letGo, .rewroteCalm], on: 20)
        #expect(!review(reflective).insights.contains { $0.kind == .tryWaiting })
    }
}
