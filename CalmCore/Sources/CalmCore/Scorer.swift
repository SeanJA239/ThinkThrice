import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Scores how impulsive a message is, from 0 (calm) to 1 (impulsive).
/// The app compares the score with `TimePolicy.threshold(at:)`.
public protocol Scorer: Sendable {
    func score(_ text: String) -> Double
}

/// A scorer with fixed answers, for tests and for pinning demo sentences.
public struct FixedScorer: Scorer {
    public var scores: [String: Double]
    public var fallback: Double

    public init(_ scores: [String: Double] = [:], fallback: Double = 0) {
        self.scores = scores
        self.fallback = fallback
    }

    public func score(_ text: String) -> Double {
        scores[text] ?? fallback
    }
}

/// The highest score of several scorers.
public struct MaxScorer: Scorer {
    public var scorers: [any Scorer]

    public init(_ scorers: [any Scorer]) {
        self.scorers = scorers
    }

    public func score(_ text: String) -> Double {
        scorers.map { $0.score(text) }.max() ?? 0
    }
}

/// Fallback until the Create ML model is ready: a small lexicon of impulsive phrases.
///
/// Workaround: the plan was to fall back to `NLTagger` sentiment, but on macOS 27
/// `NLTagger` offers no `.sentimentScore` scheme for Simplified Chinese and tags
/// every Chinese sentence `Other`. Each matched phrase adds its weight with
/// noisy-OR (1 − Π(1 − w)), so one strong phrase settles a message and several
/// weak ones add up. Sadness words are deliberately absent: 「我好难过」 must not be held.
public struct KeywordScorer: Scorer {
    public static let defaultLexicon: [String: Double] = [
        "去死": 0.95, "滚": 0.9, "混蛋": 0.85, "受够": 0.8, "骗子": 0.8, "有病": 0.8, "闭嘴": 0.8,
        "恨你": 0.75, "恶心": 0.7, "不干了": 0.7, "分手": 0.7, "傻逼": 0.9, "垃圾": 0.6,
        "凭什么": 0.6, "再也不": 0.6, "复合": 0.6, "你根本": 0.5, "每次都": 0.5, "过分": 0.5,
        "别再": 0.5, "求你": 0.5, "想你": 0.45, "我们完了": 0.6, "辞职": 0.5, "脑子": 0.4,
        "！！": 0.3, "!!": 0.3, "？？": 0.3, "??": 0.3,
    ]

    public var lexicon: [String: Double]

    public init(lexicon: [String: Double] = KeywordScorer.defaultLexicon) {
        self.lexicon = lexicon
    }

    public func score(_ text: String) -> Double {
        let calm = lexicon.reduce(1.0) { product, entry in
            text.contains(entry.key) ? product * (1 - min(1, max(0, entry.value))) : product
        }
        return 1 - calm
    }
}

#if canImport(NaturalLanguage)
/// Negative sentiment counts as impulsive. Useful for English text only; see `KeywordScorer`.
///
/// `NLTagger` returns a sentiment from -1 to 1. Neutral and positive text maps to 0,
/// so ordinary messages are never held; -1 maps to 1. Unsupported languages
/// (including Simplified Chinese on macOS 27) score 0.
public struct NLTaggerScorer: Scorer {
    public init() {}

    public func score(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let sentiment = Double(tag?.rawValue ?? "0") ?? 0
        return min(1, max(0, -sentiment))
    }
}

/// Scores with the Create ML text classifier: the probability of the `impulsive` label.
///
/// `NLModel` wraps the classifier, so `predictedLabelHypotheses` returns the
/// probability of each label. `NLModel` is documented as not thread-safe, so
/// every call takes a lock.
public final class CoreMLScorer: Scorer, @unchecked Sendable {
    public static let impulsiveLabel = "impulsive"

    private let model: NLModel
    private let label: String
    private let lock = NSLock()

    /// `compiledModelURL` points to a compiled `.mlmodelc`. Xcode compiles a
    /// `.mlmodel` in the app target into the bundle automatically.
    public init(compiledModelURL: URL, label: String = CoreMLScorer.impulsiveLabel) throws {
        self.model = try NLModel(contentsOf: compiledModelURL)
        self.label = label
    }

    /// Loads `<name>.mlmodelc` from `bundle`, or returns nil when it is not there.
    public convenience init?(bundledModelNamed name: String, in bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: name, withExtension: "mlmodelc") else { return nil }
        try? self.init(compiledModelURL: url)
    }

    public func score(_ text: String) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return model.predictedLabelHypotheses(for: text, maximumCount: 2)[label] ?? 0
    }
}
#endif
