// 来自模型组交付包（2026-11-21，v2c）。接入 CalmCore 时只加了 public / Sendable。
// 拖进 App 工程即可。同时把 ThinkThriceAnger.mlmodel（和备用的 ThinkThriceAngerLite.mlmodel）拖进工程，
// Xcode 会把它们编译成 .mlmodelc 放进 App 包里。
import CoreML
import Foundation
import NaturalLanguage

/// 粗糙版情绪分类器。
/// - 聊天消息用 `messageProbability`：切句后取最大值，对应技术文档里的 `angerProbability`。
/// - 三问的回答用 `answerProbability`：整段打分，≥ 0.8 才算「还在生气」。
public final class ThinkThriceClassifier: @unchecked Sendable {
    // @unchecked Sendable：model 只在 lock 里调用，modelName 不可变。
    public let modelName: String
    private let model: NLModel
    private let lock = NSLock()   // NLModel 是否线程安全文档没写，保守起见串行调用

    public init?(bundle: Bundle = .main) {
        for name in ["ThinkThriceAnger", "ThinkThriceAngerLite"] {
            if let url = bundle.url(forResource: name, withExtension: "mlmodelc"),
               let m = try? NLModel(contentsOf: url) {
                model = m
                modelName = name
                return
            }
        }
        return nil   // 两个都加载失败：调用方降级到规则词典
    }

    /// 测试脚本用：直接从编译好的 .mlmodelc 加载
    public init(compiledModelURL url: URL) throws {
        model = try NLModel(contentsOf: url)
        modelName = url.deletingPathExtension().lastPathComponent
    }

    public func messageProbability(_ text: String) -> Double {
        Self.splitSentences(text).map(probability).max() ?? 0
    }

    public func answerProbability(_ text: String) -> Double { probability(text) }

    /// App 启动时调用一次，避免第一条消息卡顿
    public func warmUp() { _ = probability("你好") }

    private func probability(_ s: String) -> Double {
        lock.lock(); defer { lock.unlock() }
        return model.predictedLabelHypotheses(for: s, maximumCount: 2)["angry"] ?? 0
    }

    public static func splitSentences(_ text: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in text {
            cur.append(ch)
            if "。！？!?\n".contains(ch) { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        let kept = out.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 }
        return kept.isEmpty ? [text] : kept
    }
}
