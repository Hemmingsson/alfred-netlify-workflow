import Foundation

/// The Git repository a site builds from.
public struct Repository: Codable, Equatable, Sendable {
    public var url: URL
    /// `github`, `gitlab`, `bitbucket`, …
    public var provider: String?

    public init(url: URL, provider: String? = nil) {
        self.url = url
        self.provider = provider
    }

    /// The repository's name: the last part of its URL, without `.git`.
    public var name: String {
        let last = url.lastPathComponent
        return last.hasSuffix(".git") ? String(last.dropLast(4)) : last
    }

    public var isGitHub: Bool { provider == "github" }
}
