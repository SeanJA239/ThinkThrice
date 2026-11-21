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
    func rules(_ pairs: [(String, Double)]) -> KeywordScorer {
        KeywordScorer(rules: pairs.map { KeywordRule(pattern: $0.0, weight: $0.1) })
    }

    @Test func weakRulesAddUpWithNoisyOr() {
        #expect(abs(rules([("凭什么", 0.6)]).score("凭什么") - 0.6) < 1e-9)
        #expect(abs(rules([("凭什么", 0.6), ("？？", 0.3)]).score("凭什么？？") - 0.72) < 1e-9)
        #expect(rules([("凭什么", 0.6)]).score("好的") == 0)
    }

    @Test func weakRulesSettleOnlyAtNight() {
        let score = rules([("想你", 0.45), ("！！", 0.3)]).score("我好想你！！")
        #expect(policy.shouldSettle(score: score, at: at(22, 1, 30)))
        #expect(!policy.shouldSettle(score: score, at: at(21, 14)))
    }

    @Test func plainPatternsAreLiteralAndRegexPatternsAreNot() {
        let plain = KeywordScorer(rules: [KeywordRule(pattern: "你.*每次", weight: 0.5)])
        let regex = KeywordScorer(rules: [KeywordRule(pattern: "你.{0,4}每次", weight: 0.5, regex: true)])
        #expect(plain.score("你怎么每次都这样") == 0)
        #expect(plain.score("你.*每次") == 0.5)
        #expect(regex.score("你怎么每次都这样") == 0.5)
        #expect(regex.score("你们公司的人每次") == 0)
    }

    @Test func matchesNameTheRulesThatFired() throws {
        let scorer = try KeywordScorer(json: Data(#"{"rules":[{"pattern":"滚","weight":0.9,"category":"攻击"},{"pattern":"想你","weight":0.45}]}"#.utf8))
        #expect(scorer.matches(in: "你给我滚").map(\.category) == ["攻击"])
        #expect(scorer.matches(in: "明天见").isEmpty)
    }

    @Test func invalidRulesAreRejected() {
        #expect(throws: KeywordScorer.InvalidRule.self) {
            try KeywordScorer(json: Data(#"{"rules":[{"pattern":"滚","weight":1.5}]}"#.utf8))
        }
        #expect(throws: KeywordScorer.InvalidRule.self) {
            try KeywordScorer(json: Data(#"{"rules":[{"pattern":"(你","weight":0.5,"regex":true}]}"#.utf8))
        }
    }

    /// Checks the rules the app ships in `App/Resources/Keywords.json`: they load,
    /// a clear attack settles even by day, and calm or sad messages are never held.
    @Test func appKeywordFileLoadsAndLetsSadnessThrough() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "App/Resources/Keywords.json")
        let scorer = try KeywordScorer(json: Data(contentsOf: url))
        #expect(policy.shouldSettle(score: scorer.score("你给我滚，我受够你了！"), at: at(21, 14)))
        for text in ["明天中午一起吃饭吧", "我有点难过，想和你聊聊", "我好难过", "我们明天好好谈谈吧", "收到，谢谢老板"] {
            #expect(scorer.score(text) == 0, "\(text) matched \(scorer.matches(in: text).map(\.pattern))")
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
