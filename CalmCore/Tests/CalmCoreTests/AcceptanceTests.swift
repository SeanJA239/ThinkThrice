import CoreML
import Foundation
import Testing
@testable import CalmCore

/// The model side's acceptance sentences, run like their `验收工具`: the real
/// classifier plus `ThinkThriceRules`, judged as late night, with each row's
/// recipient and scene factor.
@Suite(.serialized) struct AcceptanceTests {
    struct Row {
        let text, kind, expect, note: String
        let to: Recipient
        let ctx: Double
    }

    static func rows(_ file: String) throws -> [Row] {
        let url = try #require(Bundle.module.url(forResource: file, withExtension: "csv", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8).split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let c = line.split(separator: ",", maxSplits: 5, omittingEmptySubsequences: false).map(String.init)
            guard c.count >= 5, !c[0].hasPrefix("#") else { return nil }
            return Row(text: c[0], kind: c[1], expect: c[4], note: c.count > 5 ? c[5] : "",
                       to: Recipient(rawValue: c[2]) ?? .other, ctx: Double(c[3]) ?? 1)
        }
    }

    /// Compiles `App/Model/<name>.mlmodel`, the file the app ships.
    static func classifier(_ name: String) throws -> ThinkThriceClassifier {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "App/Model/\(name).mlmodel")
        return try ThinkThriceClassifier(compiledModelURL: MLModel.compileModel(at: url))
    }

    func check(_ file: String, model: String) throws {
        let classifier = try Self.classifier(model)
        let rows = try Self.rows(file)
        #expect(!rows.isEmpty)
        for row in rows where row.kind != "limit" {
            if row.kind == "answer" {
                let result = ThinkThriceRules.answerStillAngry(row.text, modelProb: classifier.answerProbability(row.text))
                #expect(result.angry == (row.expect == "angry"), "\(row.text)（\(row.note)）")
            } else {
                let p = classifier.messageProbability(row.text)
                let v = ThinkThriceRules.judgeMessage(row.text, modelProb: p, to: row.to, lateNight: true, contextFactor: row.ctx)
                #expect(v.lock == (row.expect == "lock"), "\(row.to.rawValue)：\(row.text) 模型 \(p) 分 \(v.score) \(v.reason.rawValue) \(v.matched)（\(row.note)）")
            }
        }
    }

    @Test(arguments: ["demo_script", "boss_probe", "demo_v2"])
    func mainModelPassesEverySentence(file: String) throws {
        try check(file, model: "ThinkThriceAnger")
    }

    /// The fallback model passes the stage script and the boss probe; on
    /// demo_v2 it is known to lock 「晚安，早点睡」 to an ex (see the handoff).
    @Test(arguments: ["demo_script", "boss_probe"])
    func liteModelPassesScriptAndBossProbe(file: String) throws {
        try check(file, model: "ThinkThriceAngerLite")
    }

    /// The app's own call path: per-contact scene factor and the day/night switch.
    @Test func judgeUsesContactFactorAndNight() throws {
        let judge = ThinkThriceJudge(classifier: try Self.classifier("ThinkThriceAnger"))
        let night = judge.judge("我想复合了", to: .ex, lateNight: true)
        #expect(night.lock)
        #expect(night.reason == .reconcile)
        #expect(night.matched == ["复合"])
        // By day a calm 「我想复合了」 goes through: only late night makes it impulsive.
        #expect(!judge.judge("我想复合了", to: .ex, lateNight: false).lock)
        #expect(!judge.judge("在吗", to: .ex, lateNight: true).lock)
        #expect(judge.judge("你是不是脑子有问题？天天让人加班", to: .boss, lateNight: false).lock)
        #expect(!judge.judge("老板我今天需要请一个病假", to: .boss, lateNight: false).lock)
    }

    @Test func verdictImpulseMatchesTheLockLine() {
        let defaults = TimePolicy(calendar: shanghai)
        let rulesOnly = ThinkThriceJudge(classifier: nil)
        for (text, to) in [("滚", Recipient.ex), ("收到，谢谢老板", .boss), ("在吗", .ex), ("你凭什么扣我工资", .boss)] {
            for night in [true, false] {
                let v = rulesOnly.judge(text, to: to, lateNight: night)
                let date = night ? at(22, 1) : at(21, 14)
                #expect(defaults.shouldSettle(score: v.impulse, at: date) == v.lock, "\(text)")
            }
        }
    }
}
