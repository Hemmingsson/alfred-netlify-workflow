import NetlifyCore

/// What the live preview web view shows for a site: its preview page, or nothing (the picture underneath shows).
struct LivePreview: Equatable, Sendable {
    /// The page path, or `about:blank`.
    let source: String

    static let hidden = LivePreview(source: "about:blank")

    var isHidden: Bool { source == Self.hidden.source }

    /// A fresh web view for `replace`: a new one per site, so back and forward stay within that site.
    var component: Component {
        .webView(id: ComponentID.livePreview, src: SafeText(source), opacity: isHidden ? 0 : 1)
    }
}
