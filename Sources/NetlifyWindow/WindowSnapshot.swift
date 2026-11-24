import NetlifyCore

/// What the window shows at one moment, read from the cache folder (never the network).
struct WindowSnapshot: Sendable {
    enum Content: Sendable {
        case empty(EmptyState)
        case sites(CachedSites)
    }

    var content: Content
    /// The last refresh failed (with a cache, the old list stays and the status line says so).
    var refreshFailure: String?
    /// A refresh job holds its lock, or one was just started.
    var isRefreshing: Bool
    /// Pictures, favicons, framing checks or a render are still coming.
    var picturesLoading: Bool

    var sites: CachedSites? {
        if case .sites(let cached) = content { cached } else { nil }
    }
}
