import Foundation

/// The search field's text, checked against a row's search text. Looser than Alfred's own filter (any substring
/// matches, not only word starts), so it never claims "no rows" while Alfred still shows some.
struct SearchQuery: Sendable {
    let words: [String]

    init(_ text: String) {
        words = text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    var isEmpty: Bool { words.isEmpty }

    /// Every word appears somewhere in `text`, in any order, ignoring case and accents.
    func matches(_ text: String) -> Bool {
        words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}
