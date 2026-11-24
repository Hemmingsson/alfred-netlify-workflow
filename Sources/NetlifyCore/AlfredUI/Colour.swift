/// A named macOS colour, as Alfred UI takes it (`labelColor`, `systemRedColor`, …).
public struct Colour: Encodable, Hashable, Sendable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }

    public static let label = Colour("labelColor")
    public static let secondaryLabel = Colour("secondaryLabelColor")
    public static let tertiaryLabel = Colour("tertiaryLabelColor")
    public static let red = Colour("systemRedColor")
    public static let orange = Colour("systemOrangeColor")
    public static let yellow = Colour("systemYellowColor")

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}
