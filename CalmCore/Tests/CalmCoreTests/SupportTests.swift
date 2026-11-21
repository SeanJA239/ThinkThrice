import Foundation
import Testing
@testable import CalmCore

@Suite struct SentencesTests {
    @Test func splitsOnSentenceAndCommaMarksKeepingThem() {
        #expect(Sentences.split("你又这样，每次都是你说了算，我受够了！") == ["你又这样，", "每次都是你说了算，", "我受够了！"])
    }

    @Test func keepsRepeatedMarksTogether() {
        #expect(Sentences.split("凭什么？？你说啊！") == ["凭什么？？", "你说啊！"])
    }

    @Test func textWithoutMarksIsOnePiece() {
        #expect(Sentences.split("我们分手吧") == ["我们分手吧"])
        #expect(Sentences.split("") == [])
    }

    @Test func piecesJoinBackToTheOriginal() {
        let text = "第一句。第二句，\n第三句?! 最后"
        #expect(Sentences.split(text).joined() == text)
    }

    @Test func composeKeepsUnrevealedPieces() {
        let original = "你又这样，每次都是你说了算，我受够了！"
        #expect(Sentences.composeRewrite(editedRevealed: "我有点难过，", original: original, revealed: 1) == "我有点难过，每次都是你说了算，我受够了！")
        #expect(Sentences.composeRewrite(editedRevealed: "算了。", original: original, revealed: 3) == "算了。")
    }
}

@Suite struct DemoClockTests {
    final class FakeRealTime: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    @Test func jumpsToNightThenFastForwardsToMorning() {
        let real = FakeRealTime(at(21, 14, 5))
        let clock = DemoClock(calendar: shanghai) { real.now }
        clock.jump(toNextHour: 1, minute: 30)
        #expect(clock.now == at(22, 1, 30))
        clock.jump(toNextHour: 9)
        #expect(clock.now == at(22, 9))
        #expect(clock.offsetFromRealTime == at(22, 9).timeIntervalSince(at(21, 14, 5)))
    }

    @Test func keepsRunningAtRealSpeedAfterAJump() {
        let real = FakeRealTime(at(21, 14))
        let clock = DemoClock(calendar: shanghai) { real.now }
        clock.jump(toNextHour: 1, minute: 30)
        real.now = at(21, 14, 2)
        #expect(clock.now == at(22, 1, 32))
        clock.reset()
        #expect(clock.now == at(21, 14, 2))
        #expect(!clock.isShifted)
    }
}

@Suite struct ScriptedTransportTests {
    @Test func repliesInScriptOrderThenGoesQuiet() async {
        let transport = ScriptedTransport(replies: ["在吗", "嗯"], replyDelay: .zero)
        var iterator = transport.incoming.makeAsyncIterator()
        await transport.send(WireMessage(text: "1", sentAt: Date()))
        #expect(await iterator.next()?.text == "在吗")
        await transport.send(WireMessage(text: "2", sentAt: Date()))
        #expect(await iterator.next()?.text == "嗯")
        await transport.send(WireMessage(text: "3", sentAt: Date()))
        let extra = await firstReply(from: transport, within: .milliseconds(200))
        #expect(extra == nil)
    }

    func firstReply(from transport: ScriptedTransport, within timeout: Duration) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await transport.incoming.first { _ in true }?.text }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
