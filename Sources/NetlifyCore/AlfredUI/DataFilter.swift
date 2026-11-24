/// A dataview's filter: the words of a placeholder (the search field) against one hidden row value, in any order.
public struct DataFilter: Encodable, Equatable, Sendable {
    /// The row value matched against.
    public var field: String
    /// What to match, e.g. `.value("searchField.text")`.
    public var match: Placeholder

    public init(field: String, match: Placeholder) {
        self.field = field
        self.match = match
    }

    private enum CodingKeys: String, CodingKey {
        case type, args, match, matchmode
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("basic", forKey: .type)
        try container.encode(field, forKey: .args)
        try container.encode(match, forKey: .match)
        try container.encode("wordmatchanyorder", forKey: .matchmode)
    }
}
