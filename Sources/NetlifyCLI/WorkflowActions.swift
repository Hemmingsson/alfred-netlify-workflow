import Foundation
import NetlifyCore

/// What `netlify action <argument>` does when the window finished.
struct WorkflowActions: Sendable {
    let context: Context

    /// open: open the URL (web addresses only); copy: copy it. Returns the text for Alfred's Post Notification
    /// object, which the workflow shows only when it isn't empty: "Copied <url>" after a copy, nothing after open.
    /// The binary never posts notifications itself.
    func perform(_ argument: FinishArgument) throws -> String {
        switch argument {
        case .open(let url):
            guard Self.isWebAddress(url) else { throw WorkflowActionError.notAWebAddress(url) }
            context.system.open(url)
            return ""
        case .copy(let text):
            context.system.copy(text)
            return "Copied \(text)"
        }
    }

    /// Only http and https: a finish argument must never open a file or launch an app through a URL scheme.
    static func isWebAddress(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && url.host() != nil
    }
}

/// Why `netlify action` refused its argument.
enum WorkflowActionError: Error, Equatable, LocalizedError {
    /// `open:` with something other than an http or https address.
    case notAWebAddress(URL)

    var errorDescription: String? {
        switch self {
        case .notAWebAddress(let url): "Not opening \(url.absoluteString): only web addresses are opened."
        }
    }
}
