import Foundation

/// Splits a chat message into the pieces the melt editor reveals one at a time.
///
/// Chat messages often have no full stops, so this splits on commas as well as
/// sentence-ending punctuation, keeping each mark with the piece before it.
/// It is rule-based rather than `NLTokenizer` so the reveal order is the same
/// on every platform and in tests.
public enum Sentences {
    static let breakers: Set<Character> = ["。", "！", "？", "!", "?", "；", ";", "，", ",", "…", "\n"]

    public static func split(_ text: String) -> [String] {
        var pieces: [String] = []
        var current = ""
        for character in text {
            if breakers.contains(character) {
                current.append(character)
            } else {
                if let last = current.last, breakers.contains(last), !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pieces.append(current)
                    current = ""
                }
                current.append(character)
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pieces.append(current)
        } else if !current.isEmpty, !pieces.isEmpty {
            pieces[pieces.count - 1] += current
        }
        return pieces
    }

    /// The text delivered after a rewrite: the user's edit of the revealed part,
    /// followed by the original pieces that were never revealed.
    public static func composeRewrite(editedRevealed: String, original: String, revealed: Int) -> String {
        let rest = split(original).dropFirst(revealed).joined()
        return editedRevealed + rest
    }
}
