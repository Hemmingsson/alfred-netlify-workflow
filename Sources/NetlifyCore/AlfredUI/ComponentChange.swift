/// The properties to change on one component: the value of an id in an `update` command, a dataview cell in a
/// row, or a row's detail pane. Nil properties are left out (Alfred keeps what was there).
public struct ComponentChange: Encodable, Equatable, Sendable {
    public var text: SafeText?
    public var colour: Colour?
    /// `contenttintcolour`: the tint of an image view or button.
    public var tint: Colour?
    public var image: Image?
    public var hidden: Bool?
    public var tooltip: SafeText?
    /// A dataview's text when it has no rows.
    public var placeholder: SafeText?
    /// A dataview's rows (and filter).
    public var data: DataSource?

    public init(
        text: SafeText? = nil,
        colour: Colour? = nil,
        tint: Colour? = nil,
        image: Image? = nil,
        hidden: Bool? = nil,
        tooltip: SafeText? = nil,
        placeholder: SafeText? = nil,
        data: DataSource? = nil
    ) {
        self.text = text
        self.colour = colour
        self.tint = tint
        self.image = image
        self.hidden = hidden
        self.tooltip = tooltip
        self.placeholder = placeholder
        self.data = data
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try encode(into: &container, prefix: "")
    }

    /// Write the properties into `container` as `<prefix><property>`; a dataview row uses the prefix `cellId.`.
    func encode(into container: inout KeyedEncodingContainer<DynamicKey>, prefix: String) throws {
        func put(_ value: (some Encodable)?, _ key: String) throws {
            if let value { try container.encode(value, forKey: DynamicKey(prefix + key)) }
        }
        try put(text, "text")
        try put(colour, "colour")
        try put(tint, "contenttintcolour")
        try put(image, "image")
        try put(hidden, "hidden")
        try put(tooltip, "tooltip")
        try put(placeholder, "placeholder")
        try put(data, "data")
    }
}
