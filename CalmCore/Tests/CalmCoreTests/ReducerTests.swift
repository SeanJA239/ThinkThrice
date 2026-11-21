import Foundation
import Testing
@testable import CalmCore

let shanghai: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return calendar
}()

/// Explicit thresholds, so these tests check the mechanism (night stricter than
/// day, inclusive boundaries) whatever the app's defaults are.
let policy: TimePolicy = {
    var policy = TimePolicy(calendar: shanghai)
    policy.nightThreshold = 0.5
    policy.dayThreshold = 0.7
    return policy
}()

func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    shanghai.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

func sent(_ text: String, score: Double, at date: Date) -> CalmMessage {
    reduce(CalmMessage(text: text, createdAt: date), .scored(score), now: date, policy: policy)
}

func apply(_ message: CalmMessage, _ events: [SettleEvent], now: Date) -> CalmMessage {
    events.reduce(message) { reduce($0, $1, now: now, policy: policy) }
}

@Suite struct ThresholdTests {
    @Test func dayThresholdIsInclusive() {
        #expect(sent("a", score: 0.7, at: at(21, 14)).state == .settling)
        #expect(sent("a", score: 0.6999, at: at(21, 14)).state == .delivered)
    }

    @Test func nightThresholdIsInclusive() {
        #expect(sent("a", score: 0.5, at: at(22, 1, 30)).state == .settling)
        #expect(sent("a", score: 0.4999, at: at(22, 1, 30)).state == .delivered)
    }

    @Test func sameScoreSettlesAtNightButNotByDay() {
        #expect(sent("a", score: 0.6, at: at(22, 1, 30)).state == .settling)
        #expect(sent("a", score: 0.6, at: at(21, 14)).state == .delivered)
    }

    @Test func nightWindowBoundaries() {
        #expect(policy.isNight(at(21, 23)))
        #expect(!policy.isNight(at(21, 22, 59)))
        #expect(policy.isNight(at(22, 5, 59)))
        #expect(!policy.isNight(at(22, 6)))
    }

    @Test func deliveredMessageRecordsScoreAndTime() {
        let m = sent("你好", score: 0.1, at: at(21, 14))
        #expect(m.lastScore == 0.1)
        #expect(m.deliveredAt == at(21, 14))
        #expect(m.settleUntil == nil)
    }
}

@Suite struct SettleDurationTests {
    @Test func beforeMidnightSettlesUntilNextMorning() {
        #expect(sent("a", score: 0.9, at: at(21, 23, 30)).settleUntil == at(22, 9))
    }

    @Test func afterMidnightSettlesUntilThisMorning() {
        #expect(sent("a", score: 0.9, at: at(22, 1, 47)).settleUntil == at(22, 9))
        #expect(sent("a", score: 0.9, at: at(22, 5, 59)).settleUntil == at(22, 9))
    }

    @Test func daySettlesFifteenMinutes() {
        #expect(sent("a", score: 0.9, at: at(21, 22, 59)).settleUntil == at(21, 23, 14))
        #expect(sent("a", score: 0.9, at: at(22, 6)).settleUntil == at(22, 6, 15))
    }

    @Test func tickMakesReadyOnlyOnceCountdownPasses() {
        let m = sent("a", score: 0.9, at: at(22, 1, 47))
        #expect(reduce(m, .tick, now: at(22, 8, 59), policy: policy).state == .settling)
        #expect(reduce(m, .tick, now: at(22, 9), policy: policy).state == .ready)
    }

    @Test func morningConfirmDelivers() {
        let ready = reduce(sent("a", score: 0.9, at: at(22, 1, 47)), .tick, now: at(22, 9), policy: policy)
        let cancelled = apply(ready, [.openConfirm, .confirmCancel], now: at(22, 9, 1))
        #expect(cancelled.state == .ready)
        let delivered = apply(ready, [.openConfirm, .confirmSend], now: at(22, 9, 1))
        #expect(delivered.state == .delivered)
        #expect(delivered.text == "a")
        #expect(delivered.deliveredAt == at(22, 9, 1))
    }

    @Test func confirmIsOnlyReachableOnceReady() {
        let settling = sent("a", score: 0.9, at: at(22, 1, 47))
        #expect(reduce(settling, .openConfirm, now: at(22, 2), policy: policy) == settling)
    }
}

@Suite struct RitualTests {
    @Test func nightRitualNeedsThreePages() {
        let m = apply(sent("a", score: 0.9, at: at(22, 1, 30)), [.startRitual], now: at(22, 1, 31))
        #expect(m.state == .ritual(step: 0, total: 3))
        let twoPages = apply(m, [.ritualNext, .ritualNext], now: at(22, 1, 32))
        #expect(twoPages.state == .ritual(step: 2, total: 3))
        let done = reduce(twoPages, .ritualNext, now: at(22, 1, 32), policy: policy)
        #expect(done.state == .delivered)
        #expect(done.text == "a")
    }

    @Test func dayRitualNeedsOnePage() {
        let m = apply(sent("a", score: 0.9, at: at(21, 14)), [.startRitual], now: at(21, 14, 1))
        #expect(m.state == .ritual(step: 0, total: 1))
        #expect(reduce(m, .ritualNext, now: at(21, 14, 1), policy: policy).state == .delivered)
    }

    @Test func abandoningRitualKeepsTheCountdown() {
        let settling = sent("a", score: 0.9, at: at(22, 1, 30))
        let abandoned = apply(settling, [.startRitual, .ritualNext, .ritualCancel], now: at(22, 1, 31))
        #expect(abandoned.state == .settling)
        #expect(abandoned.settleUntil == settling.settleUntil)
        #expect(abandoned.deliveredAt == nil)
    }

    @Test func abandoningAfterCountdownReturnsToReady() {
        let settling = sent("a", score: 0.9, at: at(21, 14))
        let abandoned = apply(settling, [.startRitual, .ritualCancel], now: at(21, 14, 20))
        #expect(abandoned.state == .ready)
    }
}

@Suite struct RewriteTests {
    let original = "你又这样，每次都是你说了算，我受够了！"

    func rewriting(at date: Date) -> CalmMessage {
        apply(sent(original, score: 0.9, at: date), [.startRewrite], now: date)
    }

    @Test func rewriteStartsWithOneSentenceAndRevealsUpToAll() {
        var m = rewriting(at: at(22, 1, 30))
        #expect(m.state == .rewriting(revealed: 1))
        m = apply(m, [.revealNext, .revealNext, .revealNext, .revealNext], now: at(22, 1, 31))
        #expect(m.state == .rewriting(revealed: 3))
    }

    @Test func calmRewriteIsDeliveredRightAway() {
        let m = apply(rewriting(at: at(22, 1, 30)), [.submitRewrite("我们明天好好聊聊吧"), .rescored(0.2)], now: at(22, 1, 32))
        #expect(m.state == .delivered)
        #expect(m.text == "我们明天好好聊聊吧")
        #expect(m.originalText == original)
        #expect(m.lastScore == 0.2)
    }

    @Test func impulsiveRewriteSettlesAgainWithoutResettingCountdown() {
        let start = rewriting(at: at(22, 1, 30))
        let m = apply(start, [.submitRewrite("你每次都这样！"), .rescored(0.8)], now: at(22, 3))
        #expect(m.state == .settling)
        #expect(m.text == "你每次都这样！")
        #expect(m.settleUntil == at(22, 9))
    }

    @Test func rescoreUsesTheThresholdAtRescoreTime() {
        // Settled at night, rewritten in the day: 0.6 is below the day threshold.
        let start = rewriting(at: at(22, 1, 30))
        let m = apply(start, [.submitRewrite("好吧"), .rescored(0.6)], now: at(22, 10))
        #expect(m.state == .delivered)
    }

    @Test func cancellingRewriteKeepsOriginalText() {
        let m = apply(rewriting(at: at(22, 1, 30)), [.revealNext, .cancelRewrite], now: at(22, 1, 31))
        #expect(m.state == .settling)
        #expect(m.text == original)
    }
}

@Suite struct LetGoTests {
    @Test func letGoWorksFromEveryHeldState() {
        let base = sent("a", score: 0.9, at: at(22, 1, 30))
        let ready = reduce(base, .tick, now: at(22, 9), policy: policy)
        let states = [
            base,
            ready,
            apply(base, [.startRitual], now: at(22, 1, 31)),
            apply(ready, [.openConfirm], now: at(22, 9)),
            apply(base, [.startRewrite], now: at(22, 1, 31)),
        ]
        for m in states {
            let gone = apply(m, [.letGo, .dissolveFinished], now: at(22, 9, 5))
            #expect(gone.state == .dissolved)
            #expect(gone.deliveredAt == nil)
        }
    }

    @Test func deliveredMessagesCannotBeLetGo() {
        let m = sent("a", score: 0.1, at: at(21, 14))
        #expect(reduce(m, .letGo, now: at(21, 14), policy: policy) == m)
    }

    @Test func heldStates() {
        #expect(SettleState.settling.isHeld)
        #expect(SettleState.rewriting(revealed: 1).isHeld)
        #expect(!SettleState.delivered.isHeld)
    }
}

@Suite struct RelaunchTests {
    let settling = sent("a", score: 0.9, at: at(22, 1, 30))

    @Test func openSheetsFallBackToSettlingWithTheSameCountdown() {
        let ritual = apply(settling, [.startRitual, .ritualNext], now: at(22, 1, 31))
        let rewriting = apply(settling, [.startRewrite], now: at(22, 1, 31))
        for m in [ritual, rewriting] {
            let restored = reduce(m, .relaunched, now: at(22, 2), policy: policy)
            #expect(restored.state == .settling)
            #expect(restored.settleUntil == at(22, 9))
        }
    }

    @Test func pendingRescoreKeepsTheRewriteAndIsReadyAfterTheCountdown() {
        let rescoring = apply(settling, [.startRewrite, .submitRewrite("好吧")], now: at(22, 1, 31))
        let restored = reduce(rescoring, .relaunched, now: at(22, 9, 30), policy: policy)
        #expect(restored.state == .ready)
        #expect(restored.text == "好吧")
    }

    @Test func confirmFallsBackToReady() {
        let confirming = apply(settling, [.tick, .openConfirm], now: at(22, 9))
        #expect(reduce(confirming, .relaunched, now: at(22, 10), policy: policy).state == .ready)
    }

    @Test func settlingThatPassedItsCountdownWhileClosedIsReady() {
        #expect(reduce(settling, .relaunched, now: at(22, 9, 1), policy: policy).state == .ready)
    }

    @Test func dissolvingIsGoneAndOtherStatesAreUnchanged() {
        let dissolving = apply(settling, [.letGo], now: at(22, 1, 31))
        #expect(reduce(dissolving, .relaunched, now: at(22, 2), policy: policy).state == .dissolved)
        let delivered = sent("b", score: 0.1, at: at(21, 14))
        #expect(reduce(delivered, .relaunched, now: at(22, 2), policy: policy) == delivered)
        let scoring = CalmMessage(text: "c", createdAt: at(22, 1))
        #expect(reduce(scoring, .relaunched, now: at(22, 2), policy: policy) == scoring)
    }

    @Test func recordsSurviveAJSONRoundTrip() throws {
        let m = apply(settling, [.startRewrite, .revealNext], now: at(22, 1, 31))
        let decoded = try JSONDecoder().decode(CalmMessage.self, from: JSONEncoder().encode(m))
        #expect(decoded == m)
    }
}
