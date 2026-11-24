import Foundation

/// What the window finished with, passed to `netlify action <argument>` by the workflow. The window writes these
/// strings (row values and ui.json), the CLI reads them back. Signing in and out happen inside the window.
public enum FinishArgument: Equatable, Sendable {
    case open(URL)
    case copy(String)

    /// The string the window finishes with.
    public var argument: String {
        switch self {
        case .open(let url): "open:" + url.absoluteString
        case .copy(let text): "copy:" + text
        }
    }

    /// Reads an argument back. It went out through `SafeText`, so the defusing is undone first.
    public init?(argument: String) {
        let argument = SafeText.restore(argument)
        if argument.hasPrefix("copy:") {
            self = .copy(String(argument.dropFirst(5)))
        } else if argument.hasPrefix("open:"), let url = URL(string: String(argument.dropFirst(5))) {
            self = .open(url)
        } else {
            return nil
        }
    }
}
