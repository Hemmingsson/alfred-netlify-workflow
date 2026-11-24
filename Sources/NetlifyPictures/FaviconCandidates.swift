import Foundation

/// The addresses to try for a site's favicon, best first: the icons its home page declares (plain `icon` and
/// `shortcut icon` before `apple-touch-icon`, in page order, `data:` URIs skipped), then `/favicon.ico` and
/// `/apple-touch-icon.png`.
struct FaviconCandidates: Equatable, Sendable {
    let urls: [URL]

    init(page html: String, at pageURL: URL) {
        var plain: [URL] = []
        var touch: [URL] = []
        for tag in html.matches(of: /<link\b[^>]*>/.ignoresCase()) {
            let attributes = Self.attributes(of: String(tag.output))
            guard let href = attributes["href"], !href.lowercased().hasPrefix("data:"),
                  let rel = attributes["rel"]?.lowercased().split(whereSeparator: \.isWhitespace),
                  let url = URL(string: Self.unescape(href), relativeTo: pageURL)?.absoluteURL
            else { continue }
            if rel.contains("icon") {
                plain.append(url)
            } else if rel.contains(where: { $0.hasPrefix("apple-touch-icon") }) {
                touch.append(url)
            }
        }
        let wellKnown = ["/favicon.ico", "/apple-touch-icon.png"].compactMap { URL(string: $0, relativeTo: pageURL)?.absoluteURL }
        var seen = Set<URL>()
        urls = (plain + touch + wellKnown).filter { seen.insert($0).inserted }
    }

    /// A tag's attributes by lower-case name; the first of a repeated one wins, as in browsers.
    private static func attributes(of tag: String) -> [String: String] {
        var attributes: [String: String] = [:]
        for match in tag.matches(of: /([A-Za-z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/) {
            let name = match.output.1.lowercased()
            if attributes[name] == nil {
                attributes[name] = String(match.output.2 ?? match.output.3 ?? match.output.4 ?? "")
            }
        }
        return attributes
    }

    /// The address without surrounding space and the HTML escapes that show up in icon addresses.
    private static func unescape(_ href: String) -> String {
        href.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
    }
}
