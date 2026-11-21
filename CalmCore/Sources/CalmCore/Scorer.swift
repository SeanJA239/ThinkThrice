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

/// One keyword trigger. The app's rules live in `App/Resources/Keywords.json`,
/// which the model side edits without touching Swift.
public struct KeywordRule: Codable, Sendable, Equatable {
    /// A plain substring, or an ICU regular expression when `regex` is true.
    public var pattern: String
    /// How impulsive a message containing it is, 0…1.
    public var weight: Double
    /// Optional label such as 攻击 or 挽回, shown with the matches in the demo panel.
    public var category: String?
    public var regex: Bool?

    public init(pattern: String, weight: Double, category: String? = nil, regex: Bool? = nil) {
        self.pattern = pattern
        self.weight = weight
        self.category = category
        self.regex = regex
    }

    func matches(_ text: String) -> Bool {
        if regex == true {
            return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        return text.range(of: pattern, options: .caseInsensitive) != nil
    }
}

/// Scores with keyword rules: every matching rule adds its weight with noisy-OR
/// (1 − Π(1 − w)), so one strong rule settles a message and several weak ones add up.
///
/// The plan's fallback was `NLTagger` sentiment, but on macOS 27 `NLTagger` has no
/// `.sentimentScore` scheme for Simplified Chinese, and the trained model only
/// separates anger from calm, so keyword rules carry the rest (late-night
/// confessions, trying to win someone back, quitting in anger). Sadness must not
/// trigger: 「我好难过」 is never held.
public struct KeywordScorer: Scorer {
    public var rules: [KeywordRule]

    public init(rules: [KeywordRule]) {
        self.rules = rules
    }

    /// Decodes `{ "rules": [ { "pattern": …, "weight": …, "category": …, "regex": … } ] }`
    /// and checks every regular expression compiles and every weight is within 0…1.
    public init(json data: Data) throws {
        struct File: Decodable { let rules: [KeywordRule] }
        let rules = try JSONDecoder().decode(File.self, from: data).rules
        for rule in rules {
            guard (0...1).contains(rule.weight) else { throw InvalidRule(rule: rule, reason: "weight must be within 0…1") }
            if rule.regex == true {
                do { _ = try NSRegularExpression(pattern: rule.pattern) } catch {
                    throw InvalidRule(rule: rule, reason: "regular expression does not compile")
                }
            }
        }
        self.rules = rules
    }

    public struct InvalidRule: Error, CustomStringConvertible {
        public let rule: KeywordRule
        public let reason: String
        public var description: String { "Keyword rule \"\(rule.pattern)\": \(reason)" }
    }

    /// The rules that match `text`, for showing why a message was held.
    public func matches(in text: String) -> [KeywordRule] {
        rules.filter { $0.matches(text) }
    }

    public func score(_ text: String) -> Double {
        1 - matches(in: text).reduce(1.0) { $0 * (1 - $1.weight) }
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
