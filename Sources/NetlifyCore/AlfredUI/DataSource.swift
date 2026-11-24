/// A dataview's `data`: its rows and its filter. Replacing `data` replaces the filter too, so send it every time.
public struct DataSource: Encodable, Equatable, Sendable {
    public var rows: [DataRow]
    public var filter: DataFilter?

    public init(rows: [DataRow], filter: DataFilter?) {
        self.rows = rows
        self.filter = filter
    }

    private enum CodingKeys: String, CodingKey {
        case type, src, filter
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("basic", forKey: .type)
        try container.encode(rows, forKey: .src)
        try container.encodeIfPresent(filter, forKey: .filter)
    }
}
