import Foundation
import Testing
@testable import CalmCore

@Suite struct FixedScorerTests {
    @Test func returnsPinnedScoreOrFallback() {
        let scorer = FixedScorer(["滚": 0.95], fallback: 0.1)
        #expect(scorer.score("滚") == 0.95)
        #expect(scorer.score("你好") == 0.1)
    }

    @Test func maxScorerTakesTheHighest() {
        let scorer = MaxScorer([FixedScorer(fallback: 0.2), FixedScorer(["x": 0.9], fallback: 0)])
        #expect(scorer.score("x") == 0.9)
        #expect(scorer.score("y") == 0.2)
    }
}

@Suite struct KeywordScorerTests {
    let scorer = KeywordScorer()

    @Test func strongPhraseSettlesDayAndNight() {
        let score = scorer.score("你给我滚")
        #expect(policy.shouldSettle(score: score, at: at(21, 14)))
        #expect(policy.shouldSettle(score: score, at: at(22, 1, 30)))
    }

    @Test func weakPhrasesAddUpWithNoisyOr() {
        let one = KeywordScorer(lexicon: ["凭什么": 0.6]).score("凭什么")
        let two = KeywordScorer(lexicon: ["凭什么": 0.6, "？？": 0.3]).score("凭什么？？")
        #expect(abs(one - 0.6) < 1e-9)
        #expect(abs(two - 0.72) < 1e-9)
    }

    @Test func weakPhraseSettlesOnlyAtNight() {
        let score = KeywordScorer(lexicon: ["想你": 0.45, "！！": 0.3]).score("我好想你！！")
        #expect(policy.shouldSettle(score: score, at: at(22, 1, 30)))
        #expect(!policy.shouldSettle(score: score, at: at(21, 14)))
    }

    @Test func calmAndSadMessagesScoreZero() {
        for text in ["明天中午一起吃饭吧", "我有点难过，想和你聊聊", "我们明天好好谈谈吧", ""] {
            #expect(scorer.score(text) == 0)
        }
    }
}

#if canImport(NaturalLanguage) && canImport(CoreML)
import CoreML

@Suite struct CoreMLScorerTests {
    /// `Fixtures/TinyImpulse.mlmodel` is a toy Create ML text classifier with the
    /// agreed labels `impulsive` / `calm`, trained on a handful of sentences only
    /// to check the integration contract. See `Fixtures/README.md`.
    func compiledFixture() throws -> URL {
        let url = try #require(Bundle.module.url(forResource: "TinyImpulse", withExtension: "mlmodel", subdirectory: "Fixtures"))
        return try MLModel.compileModel(at: url)
    }

    @Test func readsImpulsiveProbability() throws {
        let scorer = try CoreMLScorer(compiledModelURL: compiledFixture())
        let angry = scorer.score("你给我滚，我受够你了")
        let calm = scorer.score("明天中午一起吃饭吧")
        #expect((0...1).contains(angry))
        #expect((0...1).contains(calm))
        #expect(angry > calm)
    }

    @Test func missingLabelScoresZero() throws {
        let scorer = try CoreMLScorer(compiledModelURL: compiledFixture(), label: "not-a-label")
        #expect(scorer.score("你给我滚") == 0)
    }

    @Test func missingBundledModelReturnsNil() {
        #expect(CoreMLScorer(bundledModelNamed: "DoesNotExist", in: .module) == nil)
    }
}

@Suite struct NLTaggerScorerTests {
    @Test func scoresStayInRange() {
        let scorer = NLTaggerScorer()
        for text in ["你给我滚，我恨你", "今天天气真好", "", "ok"] {
            #expect((0...1).contains(scorer.score(text)))
        }
    }
}
#endif
