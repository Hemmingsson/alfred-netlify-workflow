/// Text for the window that may hold outside text (site names, commit messages, URLs). Alfred expands
/// `{var:…}`-style placeholders in whatever a script prints, so a commit message saying `{var:token}` would be
/// filled in. SafeText breaks every such placeholder when it is encoded, by putting a zero-width space after the
/// brace. Every string in the reply types is SafeText, except our own placeholders (`Placeholder`) and fixed names
/// (component ids, colours, SF Symbols).
public struct SafeText: Encodable, Hashable, Sendable, ExpressibleByStringInterpolation, CustomStringConvertible {
    /// The text as given; `encode(to:)` defuses it.
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public init(stringLiteral value: String) {
        text = value
    }

    public init(stringInterpolation: DefaultStringInterpolation) {
        text = String(stringInterpolation: stringInterpolation)
    }

    public var description: String { text }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.defuse(text))
    }

    /// The placeholder kinds Alfred UI expands.
    static let placeholderPrefixes = ["var:", "const:", "file:", "fileraw:", "value:", "data:", "param:"]
    static let breaker = "\u{200B}"

    /// `text` with a zero-width space after each `{` that starts a placeholder.
    public static func defuse(_ text: String) -> String {
        var result = ""
        var rest = text[...]
        while let brace = rest.firstIndex(of: "{") {
            result += rest[...brace]
            rest = rest[rest.index(after: brace)...]
            let start = rest.prefix(8).lowercased()
            if placeholderPrefixes.contains(where: start.hasPrefix) {
                result += breaker
            }
        }
        return result + rest
    }

    /// Undo `defuse`, for strings that come back to us from the window (finish arguments, script arguments).
    public static func restore(_ text: String) -> String {
        text.replacingOccurrences(of: "{" + breaker, with: "{")
    }
}
