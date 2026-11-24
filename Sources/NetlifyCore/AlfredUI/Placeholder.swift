/// One of our own Alfred UI placeholders, sent as is (not defused), e.g. `{value:searchField.text}`.
public struct Placeholder: Encodable, Hashable, Sendable {
    public let text: String

    /// A component getter: `{value:<path>}`.
    public static func value(_ path: String) -> Placeholder { Placeholder(text: "{value:\(path)}") }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}
