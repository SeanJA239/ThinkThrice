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
