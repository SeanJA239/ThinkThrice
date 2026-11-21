import Foundation

/// Copy that non-tech teammates edit: `Resources/Questions.json` and `Resources/Scripts.json`.
struct Content {
    struct Questions: Decodable {
        /// Night ritual pages, shown in order.
        let night: [String]
        /// Day ritual pages.
        let day: [String]
        /// The one light question when a settled message is ready.
        let morning: String

        func ritual(total: Int) -> [String] {
            let pages = total <= day.count ? day : night
            return (0..<total).map { pages.isEmpty ? "" : pages[$0 % pages.count] }
        }
    }

    struct Conversation: Decodable, Identifiable {
        let id: String
        let name: String
        /// Messages from the other side already in the chat when the app opens.
        let seed: [String]
        /// Replies, one per message the user gets delivered.
        let replies: [String]
    }

    struct Scripts: Decodable {
        let conversations: [Conversation]
    }

    let questions: Questions
    let scripts: Scripts

    static func load(bundle: Bundle = .main) -> Content {
        Content(questions: decode("Questions", bundle: bundle), scripts: decode("Scripts", bundle: bundle))
    }

    private static func decode<T: Decodable>(_ name: String, bundle: Bundle) -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            fatalError("\(name).json is missing from the app bundle")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("\(name).json is invalid: \(error)")
        }
    }
}
