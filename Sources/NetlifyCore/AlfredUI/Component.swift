/// A component built by code rather than ui.json: the live preview's web view, swapped in with `replace`.
public struct Component: Encodable, Equatable, Sendable {
    public var id: String
    /// The page: a file path or `about:blank`.
    public var src: SafeText
    public var opacity: Double

    /// A web view showing `src`, faded to `opacity`.
    public static func webView(id: String, src: SafeText, opacity: Double) -> Component {
        Component(id: id, src: src, opacity: opacity)
    }

    private enum CodingKeys: String, CodingKey {
        case type, id, src, opacity
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("webkitview", forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(src, forKey: .src)
        try container.encode(opacity, forKey: .opacity)
    }
}
